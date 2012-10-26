xnalara-shaders
===============

Real Bumpmapping for XNALara.

How to install
--------------

If you're using XPS 10.9 or higher, you don't need to do anything. These shaders are included by default.

For XNALara or earlier versions of XPS, get the `EffectsArmature.xnb` from the downloads section. Copy this file into the folder XPS_10.8.7\Content or XNALara\Content.

Background
----------

As you may know, I'm currently working on an XNALara program for Mac, and I've had a lot of help and support from the existing XNALara community, who will never be able to use my program unless they buy a new computer just for it. So partly because of that and partly because I was bored, I wanted to give something back. Specifically, working bump maps.

This file contains (almost) all the shaders used by XNALara. I have modified them to use a different (and hopefully better) way of calculating light based on bump maps. The way this is currently done in XNALara is very peculiar, and among other things, doesn't take the light direction into account except for highlights (aka specular lighting). What I've done now is a very standard way of doing normal mapping, which uses the normal map for all light calculations directly. In terms of performance, it should be about the same (in fact, my version will be slightly faster because it does less work, but only so little that you have no chance of ever noticing it). All the rest of the shading remains as it was.

This was the job of about an hour's hacking, and I haven't actually looked at the result yet – I've just had other people tell me that it works. So ideally, save the old file somewhere, try this out, and see whether you like it. If you have problems, tell me, and I'll try to fix them as soon as possible.

Known Bugs
----------

*	None at the moment

Note: There may be weirdness with some normal maps, since XNALara did not have real normal maps, and so some models were optimized for a broken target. The newest versions of XPS allow you to remap the normal map channels to fix this.

Might look like a bug but isn't
-------------------------------

I'm not sure where you set the BumpShadowAmount value, but it will not do anything anymore now. This is intentional; that feature doesn't make a lot of sense given the way bump maps are implemented now. However, instead, the shadow depth value will now apply to bumped features, too.

Final notes and thanks
----------------------

All these modifications are in the public domain (but not the original file; that's copyright Dusan, although he has made it open source). So if Dusan wants to include this in the next XNALara, or if you want to include this in your own XNALara fork, have fun!

Special thanks go to XNAaraL, for compiling the file, helping fix some compile errors and informing me of the issue with the bump maps to begin with. Thank you!

Additionally, thanks to o0Crofty0o and Love2Raid for reporting bugs!
