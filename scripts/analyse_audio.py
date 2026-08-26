"""Analyse a raw s16 stereo dump from the N64 core.

No numpy on this host, so this uses a small iterative radix-2 FFT over a
handful of windows. That is ample: we are looking for gross defects (harmonic
distortion, aliasing images, dropouts, DC offset), not fine spectral detail.
"""
import cmath, struct, sys, os

RATE = 48000

def fft(a):
    n = len(a)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit; bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    ln = 2
    while ln <= n:
        ang = -2 * cmath.pi / ln
        wl = cmath.exp(1j * ang)
        for i in range(0, n, ln):
            w = 1 + 0j
            for k in range(i, i + ln // 2):
                u = a[k]; v = a[k + ln // 2] * w
                a[k] = u + v
                a[k + ln // 2] = u - v
                w *= wl
        ln <<= 1
    return a

def main(path):
    size = os.path.getsize(path)
    total = size // 4                       # stereo s16 frames
    print("file        : %s" % path)
    print("frames      : %d  (%.1f s at %d Hz)" % (total, total / RATE, RATE))
    if total < 8192:
        print("too short"); return

    f = open(path, 'rb')
    raw = f.read(); f.close()
    L = list(struct.unpack('<%dh' % (total * 2), raw[:total * 4]))[0::2]

    # --- time-domain health ---
    peak = max(max(L), -min(L))
    dc = sum(L) / float(len(L))
    clipped = sum(1 for v in L if abs(v) >= 32700)
    # longest run of identical consecutive samples (a stall/repeat signature)
    run = best = 1
    for i in range(1, len(L)):
        if L[i] == L[i-1]:
            run += 1
            if run > best: best = run
        else:
            run = 1
    silent = sum(1 for v in L if abs(v) < 64)
    print("peak        : %d  (%.1f%% of full scale)" % (peak, 100.0*peak/32767))
    print("DC offset   : %.1f" % dc)
    print("clipped     : %d samples" % clipped)
    print("longest identical-sample run: %d" % best)
    print("near-silent : %.1f%% of samples" % (100.0*silent/len(L)))

    # --- spectrum of the loudest window ---
    N = 8192
    best_e, best_off = -1, 0
    for off in range(0, len(L) - N, N):
        e = sum(abs(v) for v in L[off:off+N])
        if e > best_e: best_e, best_off = e, off
    seg = L[best_off:best_off+N]
    # Hann window
    w = [0.5 - 0.5*cmath.cos(2*cmath.pi*i/(N-1)).real for i in range(N)]
    a = [complex(seg[i]*w[i], 0) for i in range(N)]
    fft(a)
    mag = [abs(a[i]) for i in range(N//2)]
    mx = max(mag) or 1.0
    print()
    print("loudest window at %.1f s; spectrum (dB rel peak):" % (best_off/float(RATE)))
    # report energy in bands, especially above 16k where aliasing images land
    bands = [(0,500),(500,2000),(2000,6000),(6000,12000),(12000,16000),
             (16000,20000),(20000,24000)]
    for lo, hi in bands:
        i0 = int(lo * N / RATE); i1 = int(hi * N / RATE)
        e = sum(mag[i0:i1]) / max(1, (i1-i0))
        db = 20*cmath.log10(complex(e/mx if e else 1e-9)).real
        bar = '#' * max(0, int((db + 80) / 4))
        print("  %5d-%5d Hz : %6.1f dB %s" % (lo, hi, db, bar))
    hf = sum(mag[int(16000*N/RATE):]) / max(1,(N//2 - int(16000*N/RATE)))
    lf = sum(mag[:int(16000*N/RATE)]) / max(1,int(16000*N/RATE))
    print()
    print("HF(>16k)/LF ratio: %.4f" % (hf/lf if lf else 0))
    print("  a healthy 32 kHz source resampled cleanly should have very little")
    print("  above 16 kHz; a high ratio means aliasing images or distortion.")

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'audio_dump.raw')
