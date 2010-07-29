Building Notes
==============

Prerequisites:
- Apple Developer Tools

There are two ways to build SOPE on MacOSX:
a) build using gnustep-make
b) build using Xcode >= 2.4

Option a) is usually used when you build SOPE for use with OGo, while b)
is more appropriate for SOPE:X applications or other interested
3rd parties which already have existing Xcode projects.


Building using gstep-make:
==========================

For the build just enter:
  ./configure
  make -s install
or
  make -s debug=yes install
if you build with debug information.


Building using Xcode:
=====================

For the Xcode build to succeed it is imperative to have everything built
in a central location. This can be achieved by navigating to:

Xcode -> Preferences -> Building

and select:
"Place Build Products in:" [x] Customized location:

The location itself is arbitrary, mine is: "/Local/BuildArea".


The Xcode build comes in two variants, one for development and the other
for deployment.

Development
-----------

Development usually means you're happily hacking away at your pet
projects and sometimes want to update the SOPE frameworks. For this purpose
use the "all" target and the accompanied "Development" build style. Later,
you can narrow the target down to something more specific. For development
we assume the destination for frameworks to be /Library/Frameworks.
Once you are done building all the frameworks the loader commands of the
frameworks will have that destination path built in. In order to use the
frameworks you either have to install them (by copying them manually to
their intended destination) or to prepare symlinks from
/Library/Frameworks to the place where the built products
are. I usually have symlinks from /Library/Frameworks to /Local/BuildArea
(see above) for each of the products.

Also the following products are expected to be in the following locations:
*.sax -> /Library/SaxDrivers
*.sxp -> /Library/SoProducts

Either copy them to the appropriate places or symlink them
(my suggestion).


Deployment
----------

Deployment in our terms means you want to copy all required SOPE products
into an application's app wrapper. For this step all frameworks need to be
built in a special fashion, as the "install_name" of the frameworks needs
to be prepared to point to a relative path in the app wrapper. The
situation is even more complicated as all frameworks during linking store
the "install names" of other frameworks in their mach loader commands. In
order for this step not to break we need to set up an environment which is
clearly separated from the Development environment. I chose to use
$(USER_LIBRARY_DIR)/EmbeddedFrameworks
as the default destination for these builds. In order for your application
to easily pick up the built products and copy them into its app wrapper
this location needs to be fixed and easily accessible. Note that on my
system ~/Library/EmbeddedFrameworks is a symlink to
/Library/EmbeddedFrameworks so even if you don't like the location at all
it's very easy to point it to someplace else. As soon as you have set this
up you can use the "Wrapper Contents" target with the accompanied
"Wrapper" build style to build all wrapper contents in the appropriate
fashion. When you're done you can copy all the wrapper products into your
application's wrapper. The expected destination is the "Frameworks"
directory in the wrappers "Contents" directory. For a complete list of
what you need to copy into your application's wrapper see the
"Direct Dependencies" of all "Wrapper Contents" targets in all SOPE
related projects.

The SOPE umbrella
-----------------

For Deployment purposes, the SOPE umbrella framework comes in pretty
handy. If you use it in conjunction with the "Wrapper" build style, it
will be created in
$(USER_LIBRARY_DIR)/EmbeddedFrameworks/Wrapper/SOPE.framework
and can be copied into your application's app wrapper without further
adjustments. It contains all SOPE frameworks and also guarantees that
all loader commands of the frameworks and SaxDriver bundles will have been
fixed to be relative to the SOPE.framework umbrella.


Prebinding Notes
================

NOTE: AS OF MAC OS X 10.5, PREBINDING IS DEPRECATED.
The following is left here as a reference, only.

General technical information about prebinding is available from Apple at
http://developer.apple.com/documentation/Performance/Conceptual/LaunchTime/Tasks/Prebinding.html#//apple_ref/doc/uid/20001858.

OGo frameworks currently use the range from 0xC0000000 to 0xCFFFFFFF.

Any questions and feedback regarding our use of this range should go to
Marcus Mueller <znek@mulle-kybernetik.com>.
