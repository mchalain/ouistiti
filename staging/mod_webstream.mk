
modules-$(MODULES)+=mod_webstream
slib-y+=mod_webstream
mod_webstream_SOURCES-$(SERVERHEADER)+=mod_webstream.c
mod_webstream_CFLAGS+=-I$(srcdir)src
mod_webstream_CFLAGS+=$(LIBHTTPSERVER_CFLAGS)
mod_webstream_LDFLAGS+=$(LIBHTTPSERVER_LDFLAGS)

mod_webstream_CFLAGS-$(DEBUG)+=-g -DDEBUG

