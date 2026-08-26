#!/bin/bash
R=$(ls -d ~/bpi/output/build/retroarch-*/ | head -1)
echo "=== audio_volume setting definition (range/default) ==="
grep -rn 'audio_volume' $R/configuration.c | head -3
grep -rn 'DEFAULT_AUDIO_VOLUME\|AUDIO_MAX_VOLUME\|audio_max_volume' $R/config.def.h $R/defaults.h 2>/dev/null | head -5
echo
echo "=== how it is applied ==="
grep -rn 'audio_volume' $R/audio/audio_driver.c 2>/dev/null | head -6
