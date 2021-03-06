
namespace gomovie.Widgets{

    public class Button : GtkClutter.Texture {
        public signal void clicked ();

        public Button (string icon, string fallback, string alt_fallback=""){
            set_icon (icon, fallback, alt_fallback);

            this.reactive = true;
            this.opacity = 255;
            this.enter_event.connect ( () => {
                this.save_easing_state();
	        	this.set_easing_duration(200);
	        	this.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
	        	this.set_opacity(170);
	        	this.restore_easing_state();
                return true;
            });
            this.leave_event.connect ( () => {
                this.save_easing_state();
	        	this.set_easing_duration(200);
	        	this.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
	        	this.set_opacity(255);
	        	this.restore_easing_state();
                return true;
            });

            this.button_release_event.connect ( () => {
                this.clicked ();
                return true;
            });
        }

        public void set_tooltip (string text){
            //TODO
        }

        public void set_icon (string icon, string fallback, string alt_fallback="") {
            try {

                var ti = new ThemedIcon.from_names ({icon, alt_fallback, fallback});
                var l = Gtk.IconTheme.get_default ().lookup_by_gicon (ti, 16, 0);
                if (l != null) {
                    this.set_from_pixbuf (l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null));
                } else {
                    warning("NULL detected when trying to load icon: " + icon + " (or " + fallback + ")");
                }
            } catch (Error e){warning (e.message);}
        }
    }
}
