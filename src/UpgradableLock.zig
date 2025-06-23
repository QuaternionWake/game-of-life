const std = @import("std");
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;

rw_lock: RwLock = .{},
mutex: Mutex = .{},

const Self = @This();

pub fn lock(self: *Self) void {
    self.mutex.lock();
    self.rw_lock.lock();
    self.mutex.unlock();
}

pub fn lockShared(self: *Self) void {
    self.rw_lock.lockShared();
}

pub fn lockUpgradable(self: *Self) void {
    self.mutex.lock();
    self.rw_lock.lockShared();
}

pub fn lockUpgrade(self: *Self) void {
    self.rw_lock.unlockShared();
    self.rw_lock.lock();
    self.mutex.unlock();
}

pub fn unlock(self: *Self) void {
    self.rw_lock.unlock();
}

pub fn unlockShared(self: *Self) void {
    self.rw_lock.unlockShared();
}
