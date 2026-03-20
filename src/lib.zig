const std = @import("std");

pub const Suffix = struct {
    pub const linuxdo_space = "linuxdo.space";
};

pub const LinuxDoSpaceError = error{
    InvalidArgument,
    AuthenticationFailed,
    StreamFailed,
    MailboxClosed,
    MailboxAlreadyListening,
};

pub const MailMessage = struct {
    address: []const u8,
    sender: []const u8,
    recipients: [][]const u8,
    received_at: []const u8,
    subject: []const u8,
    message_id: ?[]const u8,
    date: ?[]const u8,
    from_header: []const u8,
    to_header: []const u8,
    cc_header: []const u8,
    reply_to_header: []const u8,
    from_addresses: [][]const u8,
    to_addresses: [][]const u8,
    cc_addresses: [][]const u8,
    reply_to_addresses: [][]const u8,
    text: []const u8,
    html: []const u8,
    raw: []const u8,
    raw_bytes: []const u8,
};

pub const MailBox = struct {
    mode: []const u8,
    suffix: []const u8,
    allow_overlap: bool,
    prefix: ?[]const u8,
    pattern: ?[]const u8,
    address: ?[]const u8,
    closed: bool = false,
    activated: bool = false,
    listening: bool = false,
    queue: std.ArrayList(MailMessage),

    pub fn init(allocator: std.mem.Allocator, mode: []const u8, suffix: []const u8, allow_overlap: bool, prefix: ?[]const u8, pattern: ?[]const u8) MailBox {
        return .{
            .mode = mode,
            .suffix = suffix,
            .allow_overlap = allow_overlap,
            .prefix = prefix,
            .pattern = pattern,
            .address = if (prefix) |p| std.fmt.allocPrint(allocator, "{s}@{s}", .{ p, suffix }) catch null else null,
            .queue = std.ArrayList(MailMessage).init(allocator),
        };
    }

    pub fn deinit(self: *MailBox) void {
        self.queue.deinit();
    }

    pub fn enqueue(self: *MailBox, message: MailMessage) !void {
        if (self.closed or !self.activated) return;
        try self.queue.append(message);
    }

    pub fn listenStart(self: *MailBox) !void {
        if (self.closed) return LinuxDoSpaceError.MailboxClosed;
        if (self.listening) return LinuxDoSpaceError.MailboxAlreadyListening;
        self.activated = true;
        self.listening = true;
    }

    pub fn listenNext(self: *MailBox) ?MailMessage {
        if (self.queue.items.len == 0) return null;
        return self.queue.orderedRemove(0);
    }

    pub fn close(self: *MailBox) void {
        self.closed = true;
    }
};

const Binding = struct {
    mode: []const u8,
    suffix: []const u8,
    allow_overlap: bool,
    prefix: ?[]const u8,
    pattern_text: ?[]const u8,
    mailbox: *MailBox,

    pub fn matches(self: Binding, local_part: []const u8) bool {
        if (std.mem.eql(u8, self.mode, "exact")) {
            if (self.prefix) |p| return std.mem.eql(u8, p, local_part);
            return false;
        }
        if (self.pattern_text) |p| {
            return regexLikeMatch(local_part, p);
        }
        return false;
    }
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    base_url: []const u8,
    closed: bool = false,
    full_queue: std.ArrayList(MailMessage),
    bindings: std.StringHashMap(std.ArrayList(Binding)),

    pub fn init(allocator: std.mem.Allocator, token: []const u8, base_url: []const u8) !Client {
        if (token.len == 0) return LinuxDoSpaceError.InvalidArgument;
        try validateBaseUrl(base_url);
        return .{
            .allocator = allocator,
            .token = try allocator.dupe(u8, token),
            .base_url = try allocator.dupe(u8, base_url),
            .full_queue = std.ArrayList(MailMessage).init(allocator),
            .bindings = std.StringHashMap(std.ArrayList(Binding)).init(allocator),
        };
    }

    pub fn deinit(self: *Client) void {
        var it = self.bindings.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.bindings.deinit();
        self.full_queue.deinit();
        self.allocator.free(self.token);
        self.allocator.free(self.base_url);
    }

    pub fn bind(self: *Client, prefix: ?[]const u8, pattern: ?[]const u8, suffix: []const u8, allow_overlap: bool) !*MailBox {
        const has_prefix = prefix != null and prefix.?.len > 0;
        const has_pattern = pattern != null and pattern.?.len > 0;
        if (has_prefix == has_pattern) return LinuxDoSpaceError.InvalidArgument;

        const mode = if (has_prefix) "exact" else "pattern";
        var mailbox = try self.allocator.create(MailBox);
        mailbox.* = MailBox.init(self.allocator, mode, suffix, allow_overlap, prefix, pattern);

        const binding = Binding{
            .mode = mode,
            .suffix = suffix,
            .allow_overlap = allow_overlap,
            .prefix = prefix,
            .pattern_text = if (has_pattern) pattern.? else null,
            .mailbox = mailbox,
        };
        if (self.bindings.getPtr(suffix)) |list| {
            try list.append(binding);
        } else {
            var list = std.ArrayList(Binding).init(self.allocator);
            try list.append(binding);
            try self.bindings.put(try self.allocator.dupe(u8, suffix), list);
        }
        return mailbox;
    }

    pub fn route(self: *Client, message: MailMessage, out: *std.ArrayList(*MailBox)) !void {
        const parts = std.mem.splitScalar(u8, message.address, '@');
        var iter = parts;
        const local_part = iter.next() orelse return;
        const suffix = iter.next() orelse return;
        if (self.bindings.getPtr(suffix)) |chain| {
            for (chain.items) |binding| {
                if (!binding.matches(local_part)) continue;
                try out.append(binding.mailbox);
                if (!binding.allow_overlap) break;
            }
        }
    }

    pub fn listenNext(self: *Client) ?MailMessage {
        if (self.full_queue.items.len == 0) return null;
        return self.full_queue.orderedRemove(0);
    }

    pub fn close(self: *Client) void {
        self.closed = true;
    }

    pub fn ingestNdjsonLine(self: *Client, line: []const u8) !void {
        if (line.len == 0) return;
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, line, .{});
        defer parsed.deinit();
        const root = parsed.value;
        const t = root.object.get("type") orelse return LinuxDoSpaceError.StreamFailed;
        if (std.mem.eql(u8, t.string, "ready") or std.mem.eql(u8, t.string, "heartbeat")) return;
        if (!std.mem.eql(u8, t.string, "mail")) return;

        const raw_node = root.object.get("raw_message_base64") orelse return LinuxDoSpaceError.StreamFailed;
        const sender_node = root.object.get("original_envelope_from") orelse return LinuxDoSpaceError.StreamFailed;
        const received_node = root.object.get("received_at") orelse return LinuxDoSpaceError.StreamFailed;
        const recipients_node = root.object.get("original_recipients") orelse return LinuxDoSpaceError.StreamFailed;

        var recipients = std.ArrayList([]const u8).init(self.allocator);
        defer recipients.deinit();
        for (recipients_node.array.items) |item| {
            try recipients.append(try self.allocator.dupe(u8, item.string));
        }
        const primary = if (recipients.items.len > 0) recipients.items[0] else "";
        const decoded = try std.base64.standard.Decoder.allocDecode(self.allocator, raw_node.string);

        const message = MailMessage{
            .address = try self.allocator.dupe(u8, primary),
            .sender = try self.allocator.dupe(u8, sender_node.string),
            .recipients = try recipients.toOwnedSlice(),
            .received_at = try self.allocator.dupe(u8, received_node.string),
            .subject = "",
            .message_id = null,
            .date = null,
            .from_header = "",
            .to_header = "",
            .cc_header = "",
            .reply_to_header = "",
            .from_addresses = &[_][]const u8{},
            .to_addresses = &[_][]const u8{},
            .cc_addresses = &[_][]const u8{},
            .reply_to_addresses = &[_][]const u8{},
            .text = try self.allocator.dupe(u8, decoded),
            .html = "",
            .raw = try self.allocator.dupe(u8, decoded),
            .raw_bytes = decoded,
        };
        try self.full_queue.append(message);

        for (message.recipients) |addr| {
            var route_result = std.ArrayList(*MailBox).init(self.allocator);
            defer route_result.deinit();
            try self.route(MailMessage{
                .address = addr,
                .sender = message.sender,
                .recipients = message.recipients,
                .received_at = message.received_at,
                .subject = message.subject,
                .message_id = message.message_id,
                .date = message.date,
                .from_header = message.from_header,
                .to_header = message.to_header,
                .cc_header = message.cc_header,
                .reply_to_header = message.reply_to_header,
                .from_addresses = message.from_addresses,
                .to_addresses = message.to_addresses,
                .cc_addresses = message.cc_addresses,
                .reply_to_addresses = message.reply_to_addresses,
                .text = message.text,
                .html = message.html,
                .raw = message.raw,
                .raw_bytes = message.raw_bytes,
            }, &route_result);
            for (route_result.items) |mb| {
                const per_recipient_message = MailMessage{
                    .address = try self.allocator.dupe(u8, addr),
                    .sender = message.sender,
                    .recipients = message.recipients,
                    .received_at = message.received_at,
                    .subject = message.subject,
                    .message_id = message.message_id,
                    .date = message.date,
                    .from_header = message.from_header,
                    .to_header = message.to_header,
                    .cc_header = message.cc_header,
                    .reply_to_header = message.reply_to_header,
                    .from_addresses = message.from_addresses,
                    .to_addresses = message.to_addresses,
                    .cc_addresses = message.cc_addresses,
                    .reply_to_addresses = message.reply_to_addresses,
                    .text = message.text,
                    .html = message.html,
                    .raw = message.raw,
                    .raw_bytes = message.raw_bytes,
                };
                try mb.enqueue(per_recipient_message);
            }
        }
    }

    pub fn start(self: *Client) !void {
        if (self.closed) return;

        const auth_header = try std.fmt.allocPrint(self.allocator, "Authorization: Bearer {s}", .{self.token});
        defer self.allocator.free(auth_header);
        const stream_url = try std.fmt.allocPrint(self.allocator, "{s}/v1/token/email/stream", .{self.base_url});
        defer self.allocator.free(stream_url);

        var child = std.process.Child.init(&[_][]const u8{
            "curl",
            "-fsSL",
            "-N",
            "-H",
            auth_header,
            "-H",
            "Accept: application/x-ndjson",
            stream_url,
        }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        defer {
            if (self.closed) {
                _ = child.kill() catch {};
            }
        }

        const stdout = child.stdout orelse return LinuxDoSpaceError.StreamFailed;
        var reader = stdout.reader();

        while (!self.closed) {
            const line_opt = try reader.readUntilDelimiterOrEofAlloc(self.allocator, '\n', 1024 * 1024);
            defer if (line_opt) |line| self.allocator.free(line);
            const line = line_opt orelse break;
            const trimmed = std.mem.trim(u8, line, "\r\n\t ");
            if (trimmed.len == 0) {
                continue;
            }
            try self.ingestNdjsonLine(trimmed);
        }

        const exit_result = try child.wait();
        switch (exit_result) {
            .Exited => |code| {
                if (code != 0 and !self.closed) {
                    return LinuxDoSpaceError.StreamFailed;
                }
            },
            else => {
                if (!self.closed) {
                    return LinuxDoSpaceError.StreamFailed;
                }
            },
        }
    }
};

fn regexLikeMatch(input: []const u8, pattern: []const u8) bool {
    // Lightweight fallback matcher for SDK portability:
    // - ".*" matches everything
    // - "abc" exact match
    // - "abc.*" prefix
    // - ".*abc" suffix
    // - ".*abc.*" contains
    if (std.mem.eql(u8, pattern, ".*")) return true;
    if (pattern.len >= 4 and std.mem.startsWith(u8, pattern, ".*") and std.mem.endsWith(u8, pattern, ".*")) {
        const mid = pattern[2 .. pattern.len - 2];
        return std.mem.indexOf(u8, input, mid) != null;
    }
    if (pattern.len >= 2 and std.mem.startsWith(u8, pattern, ".*")) {
        const suffix = pattern[2..];
        return std.mem.endsWith(u8, input, suffix);
    }
    if (pattern.len >= 2 and std.mem.endsWith(u8, pattern, ".*")) {
        const prefix = pattern[0 .. pattern.len - 2];
        return std.mem.startsWith(u8, input, prefix);
    }
    return std.mem.eql(u8, input, pattern);
}

fn validateBaseUrl(url: []const u8) !void {
    if (url.len == 0) return LinuxDoSpaceError.InvalidArgument;
    if (!(std.mem.startsWith(u8, url, "https://") or std.mem.startsWith(u8, url, "http://"))) return LinuxDoSpaceError.InvalidArgument;
    if (std.mem.startsWith(u8, url, "http://")) {
        const rest = url["http://".len..];
        const host = if (std.mem.indexOfScalar(u8, rest, '/')) |idx| rest[0..idx] else rest;
        const local = std.mem.eql(u8, host, "localhost") or std.mem.eql(u8, host, "127.0.0.1") or std.mem.eql(u8, host, "::1") or std.mem.endsWith(u8, host, ".localhost");
        if (!local) return LinuxDoSpaceError.InvalidArgument;
    }
}
