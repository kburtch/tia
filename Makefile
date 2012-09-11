# Makefile for Tiny IDE for Ada/Anything
#
# Compiler Options
OPTS=-O -gnatfaon

# Include files (location of .ali files)
#INCL=-I../texttools/
# Debian
INCL=-aI/usr/share/ada/adainclude/texttools/ -aO/usr/lib/ada/adalib/texttools/

# Location of Texttools library
#LIBS=-L/usr/local/lib -ltexttools
# Debian
LIBS= -aO/usr/lib -ltexttools


all:
	gnatmake -c -i ${OPTS} ${INCL}  tia
	gnatbind -x ${INCL} tia.ali
	gnatlink tia.ali ${LIBS} -lm -lncurses

static:
	@echo "Making static binary..."
	gnatmake -c -i ${OPTS} ${INCL} tia
	gnatbind ${INCL} -x tia.ali
	gnatlink tia.ali ${LIBS} -lm -lncurses -static

help:
	@echo "Make help:"
	@echo "  all - compile TIA for GCC 3.x/GNAT 5.x or GNAT 3.x"
	@echo "  static - compile static binary"
	@echo "  clean - remove temporary files"

clean:
	rm -f tia tia.exe *.o *.ali

install:
	install -d --mode=555 /usr/share/tia
	install --mode=444 tiadefs.txt /usr/share/tia/tiadefs.txt
	install --mode=555 tia /usr/local/bin/tia

