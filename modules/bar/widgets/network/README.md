# Network speed test

The speed-test overlay and controller are adapted from Omarchy's MIT-licensed
shell; see `NOTICE-OMARCHY`. The overlay uses Omashell's theme and has no runtime
Omarchy dependency.

The measurement backend requires Python 3 and sends download and upload traffic
to Cloudflare's `speed.cloudflare.com` endpoints when the user opens the test.
It reports approximate one-second throughput samples over five seconds per
direction. Upload samples count completed requests, so they are approximate and
may differ from Omarchy's dedicated client. Closing the overlay terminates the
measurement process. Errors are shown in the overlay.
