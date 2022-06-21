const std = @import("std");
const builtin = @import("builtin");

// Description Found Here
// https://www.cmrr.umn.edu/~strupp/serial.html

const CBAUD     = 0x0000100F;
const CS5       = 0x00000000;
const CS6       = 0x00000010;
const CS7       = 0x00000020;
const CS8       = 0x00000030;
const CLOCAL    = 0x00000800;
const CRTSCTS   = 0x80000000;
const CSTOPB    = 0x00000040;
const CREAD     = 0x00000080;
const CMSPAR    = 0x40000000;
const INPCK     = 0x00000010;
const IXON      = 0x00000400;
const IXANY     = 0x00000800;
const IXOFF     = 0x00001000;
const PARENB    = 0x00000100;
const PARODD    = 0x00000200;
const VTIME     = 0x00000005;
const VMIN      = 0x00000006;
const VSWTC     = 0x00000007;
const VSTART    = 0x00000008;
const VSTOP     = 0x00000009;

const TCIFLUSH  = 0x00000000;
const TCOFLUSH  = 0x00000001;
const TCIOFLUSH = 0x00000002;
const TCFLSH    = 0x0000540B;

// Parity Not In STM32 Manuall
pub const Parity = enum {
    none,       // No Parity
    even,       // Parity On Even Words
    odd,        // Parity On Odd Words
    mark,       // Parity Always On
    space,      // Parity Always Off
};

// Stop Bit Options On STM32
pub const StopBits = enum {
    one,        // 1 Stop Bit
    two,        // 2 Stop Bits
};

// Flow Control Options On STM32
pub const FlowControl = enum {
    none,       // No Flow Control
    software,   // Software Flow Control
    hardware,   // Hardware Flow Control
};

pub const WordLength = enum {
    five,
    six,
    seven,
    eight,
};

// Standard STM32 Baud Rates Supported By Linux
pub const BaudRate = enum(u32) {
    baud1200    = 0x000004B0,
    baud1800    = 0x00000708,
    baud2400    = 0x00000960,
    baud4800    = 0x000012C0,
    baud9600    = 0x00002580,
    baud19200   = 0x00004B00,
    baud38400   = 0x00009600,
    baud57600   = 0x0000E100,
    baud115200  = 0x0001C200,
    baud230400  = 0x00038400,
    baud460800  = 0x00070800,
    baud576000  = 0x0008CA00,
    baud921600  = 0x000E1000,
};

pub const SerialPort = struct {
    baud_rate:      BaudRate    = .baud9600,
    parity:         Parity      = .none,
    stop_bits:      StopBits    = .one,
    word_length:    WordLength  = .eight,
    flowcontrol:    FlowControl = .none,

    // Functions
    // Init the structure
    pub fn init(baud_rate: BaudRate, parity: Parity, stop_bits: StopBits, word_length: WordLength, flowcontrol: FlowControl) SerialPort {
        return SerialPort {
            .baud_rate =    baud_rate,
            .parity =       parity,
            .stop_bits =    stop_bits,
            .word_length =  word_length,
            .flowcontrol =  flowcontrol,  
        };
    }

    // Configure the port on Linux
    pub fn open(self: *SerialPort, port: std.fs.File) !void {
        switch(builtin.os.tag) {
            .linux => {
                var settings = try std.os.tcgetattr(port.handle);
                
                settings.iflag = 0;
                settings.oflag = 0;
                settings.cflag = CREAD;
                settings.lflag = 0;
                settings.ispeed = 0;
                settings.ospeed = 0;

                switch (self.parity) {
                    .none   => {},
                    .odd    => settings.cflag |= PARODD,
                    .even   => {},
                    .mark   => settings.cflag |= PARODD | CMSPAR,
                    .space  => settings.cflag |= CMSPAR,
                }

                if (self.parity != .none) {
                    settings.oflag |= INPCK;
                    settings.cflag |= PARENB;
                }

                switch (self.flowcontrol) {
                    .none       => settings.cflag |= CLOCAL,
                    .software   => settings.iflag |= IXON | IXOFF,
                    .hardware   => settings.cflag |= CRTSCTS,
                }

                switch (self.stop_bits) {
                    .one => {},
                    .two => settings.cflag |= CSTOPB,
                }

                switch (self.word_length) {
                    .five   => settings.cflag |= CS5,
                    .six    => settings.cflag |= CS6,
                    .seven  => settings.cflag |= CS7,
                    .eight  => settings.cflag |= CS8,
                }

                const baudmask = baudToLinux(self.baud_rate);
                settings.cflag &= ~@as(u32, CBAUD);
                settings.cflag |= baudmask;
                settings.ispeed = baudmask;
                settings.ospeed = baudmask;

                settings.cc[VMIN] = 1;
                settings.cc[VSTOP] = 0x13; // XOFF
                settings.cc[VSTART] = 0x11; // XON
                settings.cc[VTIME] = 0;

                try std.os.tcsetattr(port.handle, .NOW, settings);


            }, 
            else => {
                @compileError("Unsupported OS");
            }
        }
    }
};

/// Flushes the serial port `port`. If `input` is set, all pending data in
/// the receive buffer is flushed, if `output` is set all pending data in
/// the send buffer is flushed.
pub fn flushSerialPort(port: std.fs.File, input: bool, output: bool) !void {
    switch (builtin.os.tag) {
        .linux => {
            if (input and output) {
                try tcflush(port.handle, TCIOFLUSH);
            }
            else if (input) {
                try tcflush(port.handle, TCIFLUSH);
            }
            else if (output) {
                try tcflush(port.handle, TCOFLUSH);
            }
        },
        else => {
            @compileError("unsupported OS, please implement!");
        }
    }
}

fn tcflush(fd: std.os.fd_t, mode: usize) !void {
    if (std.os.linux.syscall3(.ioctl, @bitCast(usize, @as(isize, fd)), TCFLSH, mode) != 0)
        return error.FlushError;
}

// Verify Baud Rate
fn baudToLinux(baud: BaudRate) u32 {
    return switch (baud) {
        .baud1200   => std.os.linux.B1200,
        .baud1800   => std.os.linux.B1800,
        .baud2400   => std.os.linux.B2400,
        .baud4800   => std.os.linux.B4800,
        .baud9600   => std.os.linux.B9600,
        .baud19200  => std.os.linux.B19200,
        .baud38400  => std.os.linux.B38400,
        .baud57600  => std.os.linux.B57600,
        .baud115200 => std.os.linux.B115200,
        .baud230400 => std.os.linux.B230400,
        .baud460800 => std.os.linux.B460800,
        .baud576000 => std.os.linux.B576000,
        .baud921600 => std.os.linux.B921600,
    };
}
