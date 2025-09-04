pub const KinectFrame = struct {
    data: []u8,
    timestamp: u32,
    width: usize,
    height: usize,
    type: enum { rgb, depth },
};
