import io, re
p = 'scripts/audio_watch.sh'
s = io.open(p, encoding='utf-8', newline='').read()

new_hdr = (
"#   avail_max  - NOT USABLE on this driver. It was expected to be a persistent\n"
"#                high-water mark, but measurement shows it oscillates and\n"
"#                resets continuously (4608 -> 1512 -> 136 -> 72 inside one\n"
"#                second), so tracking its rises produced ~15000 spurious\n"
"#                events in 25 s. Ignored entirely. The earlier claim that it\n"
"#                'cannot miss an event' was simply wrong.\n"
"#\n"
"# What IS trustworthy:\n"
"#   delay      - the margin, sampled at ~700 Hz. A real collapse lasts far\n"
"#                longer than 1.4 ms, so sampling does catch it.\n"
"#   hw_ptr going backwards - an unambiguous full underrun.\n"
)
s = re.sub(r'#   avail_max  - high-water mark.*?near-misses\.\n', new_hdr, s, flags=re.S)

# remove the avail_max tracking block inside the loop
s = re.sub(r'  # avail_max is reset by the kernel.*?\n  fi\n', '', s, flags=re.S)

# drop avail_max from the dip log line and the summary
s = s.replace(' ${avm:-?} $st', ' $st')
s = re.sub(r'  echo "# worst avail_max[^\n]*\n', '', s)
s = s.replace('LASTHW=0; MAXAVAIL=0', 'LASTHW=0')
s = s.replace('      avail_max) avm=$v ;;\n', '')
s = s.replace('    avail_max) avm=$v ;;\n', '')
s = s.replace('  st=""; dly=""; av=""; avm=""; hw=""', '  st=""; dly=""; hw=""')
s = s.replace('      avail)     av=$v ;;\n', '')
s = s.replace('columns: uptime delay_frames delay_ms avail_max state',
              'columns: uptime delay_frames delay_ms state')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('NEWWORST left:', s.count('NEWWORST'))
print('REARM left   :', s.count('REARM'))
print('avm refs left:', s.count('avm'))
print('MAXAVAIL left:', s.count('MAXAVAIL'))
