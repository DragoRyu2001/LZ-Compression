const std = @import("std");

pub fn main() !void {}
pub const LZCompression: type = struct {
    pub fn compression(filePath: []const u8) !void {
        var file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();

        var buffer: [100]u8 = undefined;
        try file.seekTo(0);
        const bytes_read = try file.readAll(&buffer);

        for (buffer, 0..) |byte, index| {
            var j: usize = index;
            while (j >= 0) : (j -= 1) {

            }
        }
    }
};
