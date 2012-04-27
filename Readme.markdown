Zero MQ For IOS
===============

I am starting with the standard 3.1.1 ZeroMQ library and making a packaged
version for the iPhone/iPad/iPod Touch.  Why you might ask?  Because it's 
there?  No, because having a high performance messaging engine attached 
to a whole bunch of devices in the field that are almost always connected
creates some fascinating possibilities.

Update 1 4/27/2012
------------------

*READ THIS*
There is an issue LIBZMQ-270(http://zeromq.jira.com/LIBZMQ-270) which
may be causing the pub sub test to fail.  I can reproduce the problem
using simple C++ programs executing PUB/SUB behavior.  One of my
tests (which weren't fantastic to begin with) are not working.  Be
advised.


