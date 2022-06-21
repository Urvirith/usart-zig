const std = @import("std");
const usart = @import("usart.zig");

// Main Call 
pub fn main() anyerror!u8 {    
    try loop();
    
    return 0;
}

fn loop() !void {
    const port_name = "/dev/ttyUSB0";
    //var buffer: [1024]u8 = undefined;
    var bufferusb: [1024]u8 = undefined;

    var dev = std.fs.cwd().openFile(port_name, .{ .read = true, .write = true }) catch |err| switch (err) {
        error.FileNotFound => {
            try std.io.getStdOut().writer().print("The serial port {s} does not exist.\n", .{port_name});
            return;
        },
        else => return err,
    };
    defer dev.close();

    var config = usart.SerialPort.init(
        usart.BaudRate.baud4800, 
        usart.Parity.none, 
        usart.StopBits.one, 
        usart.WordLength.eight,
        usart.FlowControl.none
    );

    try config.open(dev);
    
    while (true) {
        // Read the USB or Keyboard input
        try std.io.getStdOut().writer().writeAll("Please Enter A Value: ");
        
        // Trims Out The Delimiter
        var usbslice = try std.io.getStdIn().reader().readUntilDelimiter(&bufferusb, '\n');
        // Remove The Horizonal Tab Character: \t to get scanned valuable info
        var usblen = usbslice.len - 1;
        // Reform the slice from the buffer with the carrage return

        if ((usblen > 0) and ((usblen + 2) < bufferusb.len)) {
            var usbin = bufferusb[0..usbslice.len + 1];
            // Add A Carrage Return To Pad For The Scan
            //usbin[usblen] = '\n';

            // Serial Write On All Data Recieved
            switch(usblen) {
                5 => { // Trace Code
                    try std.io.getStdOut().writer().print("Trace Code: {s}", .{usbin});
                    try dev.writer().writeAll(usbin);
                },
                6 => { // Shop Order
                    try std.io.getStdOut().writer().print("Shop Order: {s}", .{usbin});
                    try dev.writer().writeAll(usbin);
                    try shoporder();
                },
                8 => { // Catalogue Number
                    try std.io.getStdOut().writer().print("Catalogue Number: {s}", .{usbin});
                    try dev.writer().writeAll(usbin);
                },
                else => { // Assume Catalogue Number
                    try std.io.getStdOut().writer().print("Assumed Catalogue Number: {s}", .{usbin});
                    try dev.writer().writeAll(usbin);
                }
            }
        }
    }
}

// Handle the shop order information
fn shoporder() !void {
    try std.io.getStdOut().writer().writeAll("Shop Order Found. \n");
}
