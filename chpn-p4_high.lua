-- HIGH sender generated from MIDI
local modem = peripheral.wrap("top")
assert(modem, "No modem on 'top'")
local timepassed = 0.0

sleep(60.330362)
modem.transmit(9402, 0, textutils.serialize({ t="PLAY", duration=0.80831 }))
sleep(2.407012999999999)
modem.transmit(9407, 0, textutils.serialize({ t="PLAY", duration=0.377358 }))
sleep(1.548240000000007)
modem.transmit(9402, 0, textutils.serialize({ t="PLAY", duration=0.392157 }))
