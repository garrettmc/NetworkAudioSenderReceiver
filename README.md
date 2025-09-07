# NetworkAudioSenderReceive
Code run on two Raspberry Pi's to stream audio over a network. I use this to strem from a Record Player in one room to my audio distribution server in another.

# Raspberry Pis
Setup the Raspberry pi's. Hook a USB audio interface up to the USB port on each Pi. Run audio from the Record Player to the sender's USB audio interface input channels, and the receivers to your output device.

# Sender
Copy the files in the Sender directory to the various directories on the Raspberry Pi.
~~~
  in-etc-logrotate.d-dir --> /etc/logrotate.d/
  in-etc-systemd-system-dir --> /etc/systemd/system/
  in-usr-local-bin-dir --> /usr/local/bin/
~~~

Install dependencies:
~~~
  sudo apt install ffmpeg sox alsa-utils pulseaudio netcat-openbsd mbuffer
~~~

Create the file ~/.asoundrc, with this contents (this avoids sharing errors with the device):
pcm.dsnooper {
    type dsnoop
    ipc_key 1024
    slave {
        pcm "hw:2,0"
        channels 2
        rate 44100
    }
}


Start daemon:
~~~
chmod +x /usr/local/bin/receiver.sh
sudo systemctl enable audiostream-sender
sudo systemctl start audiostream-sender

~~~

# Receiver
Do the same as Sender, just using the Receiver directory and renaming anything with "sender" to "receiver".

# Setup Changes
In the etc/systemd/system files, replace the "iot" username with the user name setup on the Pi.

On each Pi, find the USB audio device:
~~~
   arecord -l
~~~
Find the card, it'll look like this:
~~~
   card 2: CODEC [USB Audio CODEC], device 0: USB Audio [USB Audio]
~~~
This means card #2, device 0. So, in the scripts, replace the DEVICE= line:
~~~
  DEVICE="hw:2,0"
~~~

On the sender's script, replace
~~~
  STREAM_DEST=
~~~
With the IP address or name of the receiver Raspberry Pi (I called my sender turntable, and my reciever as turntable2, so I used turntable2.local).

# Logs
You can tail the logs for errors/etc:

On sender:
~~~
  tail -f /var/log/audio_sender.log
~~~
On receiver:
~~~
  tail -f /var/log/audio_receiver.log
~~~

# Periodic tiny gaps in sound.
If you periodically get some small silent sections (maybe a half second). Some things to try:

- 1. Increase mbuffer prefill slightly
Try setting it to buffer 500ms (≈88 KB) instead of 5ms: -P 88. So update your receiver.sh line to:

~~~
mbuffer -q -m 2M -P 88
~~~

- 2. Use aplay with explicit buffer/period settings. You can give aplay a larger internal buffer so it doesn't underrun easily:

~~~
aplay -D hw:2,0 -t raw -f S16_LE -r 44100 -c 2 --buffer-time=500000 --period-time=100000
~~~

This sets:

- Buffer: 500ms (44100 samples × 2 channels × 2 bytes = ~176kB)
- Period: 100ms chunks (smoother feeding)
