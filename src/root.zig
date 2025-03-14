const std = @import("std");
const LZCompression = @import("main.zig").LZCompression;
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic encoding data" {
    testing.log_level = .debug;
    const file = try std.fs.cwd().createFile(
        "junk_file.txt",
        .{ .read = true },
    );
    defer file.close();

    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);

    try file.writeAll("Hi Guys! this is a test file to check if this log works or not!!\n And the fun part is the more I write in this file the more it should try to optimize this file for me!!\n Hopefully, this does not break anywhere(fingers crossed)");
    try LZCompression.compressFile(file, gpa_alloc.allocator());
    try std.fs.cwd().deleteFile("junk_file.txt");
}
test "lorem" {
    testing.log_level = .debug;
    std.log.debug("Test 2", .{});
    const file = try std.fs.openFileAbsolute(
        "C:\\Users\\Sanch\\Documents\\Personal\\LZ-Compression\\test_cases\\lorem_ipsum_40KB.txt",
        .{},
    );
    defer file.close();

    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);

    // try file.writeAll("Hi Guys! this is a test file to check if this log works or not!!\n And the fun part is the more I write in this file the more it should try to optimize this file for me!!\n Hopefully, this does not break anywhere(fingers crossed)");
    try LZCompression.compressFile(file, gpa_alloc.allocator());
}

test "big_lorem" {
    testing.log_level = .debug;
    std.log.debug("Test 2", .{});
    const file = try std.fs.openFileAbsolute(
        "C:\\Users\\Sanch\\Documents\\Personal\\LZ-Compression\\test_cases\\lorem_ipsum_64KB.txt",
        .{},
    );
    defer file.close();

    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);

    // try file.writeAll("Hi Guys! this is a test file to check if this log works or not!!\n And the fun part is the more I write in this file the more it should try to optimize this file for me!!\n Hopefully, this does not break anywhere(fingers crossed)");
    try LZCompression.compressFile(file, gpa_alloc.allocator());
}
