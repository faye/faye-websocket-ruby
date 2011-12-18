#include <ruby.h>

VALUE Faye = Qnil;
VALUE FayeWebSocket = Qnil;
VALUE FayeWebSocketMask = Qnil;

void Init_faye_websocket_mask();
VALUE method_faye_websocket_mask(VALUE self, VALUE payload, VALUE mask);

void Init_faye_websocket_mask() {
  Faye = rb_define_module("Faye");
  FayeWebSocket = rb_define_class_under(Faye, "WebSocket", rb_cObject);
	FayeWebSocketMask = rb_define_module_under(FayeWebSocket, "Mask");
	rb_define_singleton_method(FayeWebSocketMask, "mask", method_faye_websocket_mask, 2);
}

VALUE method_faye_websocket_mask(VALUE self, VALUE payload, VALUE mask) {
  int n = RARRAY_LEN(payload), i, p, m;
  VALUE unmasked = rb_ary_new2(n);
  
  for (i = 0; i < n; i++) {
    p = NUM2INT(rb_ary_entry(payload, i));
    m = NUM2INT(rb_ary_entry(mask, i % 4));
    rb_ary_store(unmasked, i, INT2NUM(p ^ m));
  }
  return unmasked;
}

