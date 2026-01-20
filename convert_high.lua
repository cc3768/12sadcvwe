-- HIGH sender generated from MIDI
local modem = peripheral.wrap("top")
assert(modem, "No modem on 'top'")
local timepassed = 0.0

sleep(16.775)
modem.transmit(9408, 0, textutils.serialize({ t="PLAY", duration=0.08125 }))
sleep(10.850000000000001)
modem.transmit(9405, 0, textutils.serialize({ t="PLAY", duration=0.104167 }))
sleep(15.71875)
modem.transmit(9404, 0, textutils.serialize({ t="PLAY", duration=0.151042 }))
sleep(0.1510419999999968)
modem.transmit(9404, 0, textutils.serialize({ t="PLAY", duration=0.069792 }))
sleep(3.845833000000006)
modem.transmit(9408, 0, textutils.serialize({ t="PLAY", duration=0.092708 }))
sleep(38.756249999999994)
modem.transmit(9407, 0, textutils.serialize({ t="PLAY", duration=0.151042 }))
sleep(1.7770830000000046)
modem.transmit(9406, 0, textutils.serialize({ t="PLAY", duration=0.08125 }))
