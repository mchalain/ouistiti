WS_SRC:=websocket/
WEBSOCKET_RT:=$(if $(findstring yy,$(WEBSOCKET_RT)$(SHARED)),y,n)
lib-$(WEBSOCKET_RT)+=ouistiti_ws
ouistiti_ws_SOURCES+=websocket.c utils.c
ouistiti_ws_LIBS+=dl
ouistiti_ws_CFLAGS+=$(LIBHTTPSERVER_CFLAGS)
ouistiti_ws_CFLAGS-$(DEBUG)+=-g -DDEBUG
ouistiti_ws_LIBS+=websocket
ouistiti_ws_LDFLAGS+=$(LIBHTTPSERVER_LDFLAGS)

ifneq ($(USE_PTHREAD),y)
  WS_ECHO=n
  WS_CHAT=n
  WS_JSONRPC=n
  WS_GPS=n
  WS_SYSLOGD=n
endif

bin-$(WS_ECHO)+=websocket_echo
websocket_echo_SOURCES+=$(WS_SRC)echo.c
websocket_echo_LDFLAGS-$(WEBSOCKET_RT)+=$(LIBHTTPSERVER_LDFLAGS)
websocket_echo_LIBS-$(WEBSOCKET_RT)+=ouistiti_ws websocket c
websocket_echo_LIBS+=pthread

websocket_echo_CFLAGS-$(DEBUG)+=-g -DDEBUG

bin-$(WS_GPS)+=websocket_gps
websocket_gps_SOURCES+=$(WS_SRC)nmea.c
websocket_gps_CFLAGS+=-DPTHREAD
websocket_gps_LDFLAGS-$(WEBSOCKET_RT)+=$(LIBHTTPSERVER_LDFLAGS)
websocket_gps_LIBS-$(WEBSOCKET_RT)+=ouistiti_ws websocket
websocket_gps_LIBS+=pthread nmea

websocket_gps_CFLAGS-$(DEBUG)+=-g -DDEBUG

bin-$(WS_CHAT)+=websocket_chat
websocket_chat_SOURCES+=$(WS_SRC)chat.c
websocket_chat_CFLAGS+=-DPTHREAD
websocket_chat_LDFLAGS-$(WEBSOCKET_RT)+=$(LIBHTTPSERVER_LDFLAGS)
websocket_chat_LIBS-$(WEBSOCKET_RT)+=ouistiti_ws websocket
websocket_chat_LIBS+=pthread

websocket_chat_CFLAGS-$(DEBUG)+=-g -DDEBUG

bin-$(WS_CHAT)+=client_chat
client_chat_SOURCES+=$(WS_SRC)client_chat.c
client_chat_CFLAGS+=-DPTHREAD
client_chat_CFLAGS-$(DEBUG)+=-g -DDEBUG

ifeq ($(MODULES),y)

bin-$(WS_JSONRPC)+=websocket_jsonrpc
websocket_jsonrpc_SOURCES+=$(WS_SRC)jsonrpc.c
websocket_jsonrpc_SOURCES+=jsonrpc/jsonrpc.c
websocket_jsonrpc_LDFLAGS-$(WEBSOCKET_RT)+=$(LIBHTTPSERVER_LDFLAGS)
websocket_jsonrpc_LIBS-$(WEBSOCKET_RT)+=ouistiti_ws websocket c
websocket_jsonrpc_LIBS+=dl jansson
websocket_jsonrpc_CFLAGS-$(PTHREAD)+=-DPTHREAD
websocket_jsonrpc_LIBS-$(PTHREAD)+=pthread
websocket_jsonrpc_CFLAGS-$(DEBUG)+=-g -DDEBUG

modules-$(WS_JSONRPC)+=jsonsql
jsonsql_SOURCES+=$(WS_SRC)jsonsql.c
jsonsql_LIBRARY+=sqlite3
jsonsql_CFLAGS-$(DEBUG)+=-g -DDEBUG

modules-$(WS_JSONRPC)+=authrpc
authrpc_SOURCES+=$(WS_SRC)authrpc.c
authrpc_LIBRARY+=sqlite3
authrpc_LIBS+=ouihash
authrpc_LIBS-$(MBEDTLS)+=mbedcrypto
authrpc_CFLAGS-$(DEBUG)+=-g -DDEBUG
authrpc_CFLAGS+=$(LIBHTTPSERVER_CFLAGS)
authrpc_LDFLAGS+=$(LIBHTTPSERVER_LDFLAGS)

else
bin-$(WS_JSONRPC)+=websocket_authrpc
websocket_authrpc_SOURCES+=$(WS_SRC)jsonrpc.c
websocket_authrpc_SOURCES+=jsonrpc/jsonrpc.c
websocket_authrpc_SOURCES+=$(WS_SRC)authrpc.c
websocket_authrpc_LIBS-$(WEBSOCKET_RT)+=ouistiti_ws websocket c
websocket_authrpc_LIBS+=jansson
websocket_authrpc_LIBRARY+=sqlite3
websocket_authrpc_LIBS+=ouihash
websocket_authrpc_CFLAGS+=$(LIBHTTPSERVER_CFLAGS)
websocket_authrpc_LDFLAGS+=$(LIBHTTPSERVER_LDFLAGS)
websocket_authrpc_LIBS-$(MBEDTLS)+=mbedcrypto
websocket_authrpc_CFLAGS-$(PTHREAD)+=-DPTHREAD
websocket_authrpc_LIBS-$(PTHREAD)+=pthread
websocket_authrpc_CFLAGS-$(DEBUG)+=-g -DDEBUG

endif

bin-$(WS_SYSLOGD)+=websocket_syslogd
websocket_syslogd_SOURCES+=$(WS_SRC)syslogd.c
websocket_syslogd_CFLAGS-$(WEBSOCKET_RT)+=-DPTHREAD
websocket_syslogd_LDFLAGS-$(WEBSOCKET_RT)+=$(LIBHTTPSERVER_LDFLAGS)
websocket_syslogd_LIBS-$(WEBSOCKET_RT)+=ouistiti_ws websocket c pthread

websocket_syslogd_CFLAGS-$(DEBUG)+=-g -DDEBUG
