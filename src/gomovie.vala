using Gtk;
using Gst;
[CCode (cname="gst_navigation_query_parse_commands_length")]
public extern bool gst_navigation_query_parse_commands_length (Gst.Query q, out uint n);
[CCode (cname="gst_navigation_query_parse_commands_nth")]
public extern bool gst_navigation_query_parse_commands_nth (Gst.Query q, uint n, out Gst.NavigationCommand cmd);

namespace gomovie {
	public class App : Window {
	
	    /*private DrawingArea drawing_area;
	    private Pipeline pipeline;
	    private Element src;
	    private Element sink;
	    private ulong xid;*/
	
		construct {
            //program_name = "goMovie";
            //exec_name = "gomovie";

            //build_data_dir = Constants.DATADIR;
            //build_pkg_data_dir = Constants.PKGDATADIR;
            //build_release_name = Constants.RELEASE_NAME;
            //build_version = Constants.VERSION;
            //build_version_info = Constants.VERSION_INFO;

            //app_years = "2011-2012";
            //app_icon = "gomovie";
            //app_launcher = "gomovie.desktop";
            //application_id = "net.launchpad.gomovie";

            //main_url = "https://code.launchpad.net/gomovie";
            //bug_url = "https://bugs.launchpad.net/gomovie";
            //help_url = "https://code.launchpad.net/gomovie";
            //translate_url = "https://translations.launchpad.net/gomovie";

            /*about_authors = {""};
            about_documenters = {""};
            about_artists = {""};
            about_translators = "Launchpad Translators";
            about_comments = "To be determined"; */
            //about_license_type = Gtk.License.GPL_3_0;
        }
		///
		public Settings						settings;
		public ClutterGst.VideoTexture		canvas;
        public gomovie.Widgets.TagView		tagview;
        public gomovie.Widgets.Controls		controls;
        public Clutter.Stage				stage;
        public bool							fullscreened;
        public uint							hiding_timer;
        public GnomeMediaKeys				mediakeys;
        public gomovie.Widgets.Playlist		playlist;
        public gomovie.Widgets.TopPanel		panel;
        public GtkClutter.Embed				clutter;
        public Granite.Widgets.Welcome		welcome;

        private float video_w;
        private float video_h;
        private bool  reached_end;
        private bool  error;

        public bool has_dvd;

        public bool         playing;
        public File         current_file;
        public GLib.List<string> last_played_videos; //taken from settings, but splitted

        public GLib.VolumeMonitor monitor;

        public bool moving_action;
        ///
        int flags;
	    public App () {
	    	Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
	    	this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;

            this.fullscreened = false;

            this.playlist   = new Widgets.Playlist ();
            this.settings   = new Settings ();
            this.canvas     = new ClutterGst.VideoTexture ();
            
            this.tagview    = new Widgets.TagView (this);
            this.panel      = new Widgets.TopPanel ();

            var mainbox     = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            this.clutter    = new GtkClutter.Embed ();
            this.stage      = (Clutter.Stage)clutter.get_stage ();
            this.controls   = new Widgets.Controls (this);

			this.welcome = new Granite.Widgets.Welcome (_("No videos are open"), _("Select a source to begin playing"));
            welcome.append ("document-open", _("Open file"), _("Open a saved file."));
            
            //prepare last played videos
            this.last_played_videos = new GLib.List<string> ();
            var split = settings.last_played_videos.split (",");
            for (var i=0;i<split.length;i++){
                this.last_played_videos.append (split[i]);
            }

            this.has_dvd = gomovie.has_dvd ();
            
            if (settings.last_folder == "-1")
                settings.last_folder = Environment.get_home_dir ();
            welcome.append ("internet-web-browser", _("Open a location"), _("Watch something from the infinity of the internet"));
            string filename = "";
            if (last_played_videos.length () > 0) {
                filename = last_played_videos.nth_data (0);
                //welcome.append ("media-playback-start", _("Resume last video"), get_title (File.new_for_uri (filename).get_basename ()));
            }
            if (has_dvd)
                welcome.append ("media-cdrom", _("Play from Disc"), _("Watch a DVD or open a file from disc"));            

			// UI 
            this.canvas.reactive = true;
            this.canvas.width    = 624;
            this.canvas.height   = 352;

            this.controls.y = Gdk.Screen.get_default ().height (); //place it somewhere low

            stage.add_child (canvas);
            stage.add_child (tagview);
            stage.add_child (controls.background);
            stage.add_child (controls);
            stage.add_child (panel);
            stage.color = Clutter.Color.from_string ("#000");

			this.panel.hide ();

            this.tagview.y      = -5;
            this.tagview.x      = stage.width;
            this.tagview.add_constraint (new Clutter.BindConstraint (stage,
                Clutter.BindCoordinate.HEIGHT, -10));



            this.controls.play.set_tooltip (_("Play"));
            this.controls.open.set_tooltip (_("Open"));
            this.controls.view.set_tooltip (_("Sidebar"));
            this.panel.exit.set_tooltip (_("Leave Fullscreen"));

            mainbox.pack_start (welcome);
            mainbox.pack_start (clutter);

            this.title = "goMovie";
            this.icon_name = "gomovie";
            this.window_position = Gtk.WindowPosition.CENTER;
            
            this.add (mainbox);
            this.set_default_size (624, 352);
            this.set_size_request (624, 352);
            
            if (!settings.show_window_decoration)
                this.decorated = false;

            clutter.hide ();
            
            
            // events
            // if langs or subs change, rescan
            dynamic Gst.Pipeline el = this.canvas.get_pipeline ();
            el.text_tags_changed.connect (tagview.setup_text_setup);
            el.audio_tags_changed.connect (tagview.setup_audio_setup);
            
            //look for dvd
            this.monitor = GLib.VolumeMonitor.get ();
            monitor.drive_connected.connect ( (drive) => {
                this.has_dvd = gomovie.has_dvd ();
                welcome.set_item_visible (1, this.has_dvd);
            });
            monitor.drive_disconnected.connect ( () => {
                this.has_dvd = gomovie.has_dvd ();
                welcome.set_item_visible (1, this.has_dvd);
            });
            //playlist wants us to open a file
            playlist.play.connect ( (file) => {
                this.current_file = file;
                this.play_file ();
            });
            
            //handle welcome
            welcome.activated.connect ( (index) => {
				if (filename == "" && index == 1)
					index = 2;
                switch (index) {
                case 0:
                    run_open (0);
                    break;
                case 1:
					open_file (filename);
					canvas.get_pipeline ().set_state (Gst.State.PAUSED);
					this.canvas.progress = double.parse (last_played_videos.nth_data (1));
					canvas.get_pipeline ().set_state (Gst.State.PLAYING);
					toggle_play (true);
					welcome.hide ();
					clutter.show_all ();
					break;
				case 2:
					run_open (2);
					break;
                default:
                    var d = new Gtk.Dialog.with_buttons (_("Open location"),
                        this, Gtk.DialogFlags.MODAL,
                        Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.Stock.OK,     Gtk.ResponseType.OK);
                    var grid  = new Gtk.Grid ();
                    var entry = new Gtk.Entry ();

                    grid.attach (new Gtk.Image.from_icon_name ("internet-web-browser",
                        Gtk.IconSize.DIALOG), 0, 0, 1, 2);
                    grid.attach (new Gtk.Label (_("Choose location")), 1, 0, 1, 1);
                    grid.attach (entry, 1, 1, 1, 1);

                    ((Gtk.Container)d.get_content_area ()).add (grid);
                    grid.show_all ();

                    if (d.run () == Gtk.ResponseType.OK) {
                        open_file (entry.text, true);
                        canvas.playing = true;
                        welcome.hide ();
                        clutter.show_all ();
                    }
                    d.destroy ();
                    break;
                }
            });
            
            //video size changed
            this.canvas.size_change.connect ( () => {
                this.place (true);
            });
            //check for errors on pipe's bus
            this.canvas.error.connect ( () => {
                warning ("An error occured");
                this.error = true;
            });
            this.canvas.get_pipeline ().get_bus ().add_signal_watch ();
            
            this.canvas.get_pipeline ().get_bus ().message.connect ( () => {
                var msg = this.canvas.get_pipeline ().get_bus ().peek ();
                if (msg == null)
                    return;
                switch (msg.type) {
                    case Gst.MessageType.ERROR:
                        GLib.Error e;
                        string detail;
                        msg.parse_error (out e, out detail);
                        warning (e.message);
                        debug (detail);
                        this.canvas.get_pipeline ().set_state (Gst.State.NULL);
                        this.error = true;

                        var dlg  = new Gtk.Dialog.with_buttons (_("Error"), this,
                            Gtk.DialogFlags.MODAL, Gtk.Stock.OK, Gtk.ResponseType.OK);
                        var grid = new Gtk.Grid ();
                        var err  = new Gtk.Image.from_stock (Gtk.Stock.DIALOG_ERROR,
                            Gtk.IconSize.DIALOG);

                        err.margin_right = 12;
                        grid.margin = 12;
                        grid.attach (err, 0, 0, 1, 1);
                        grid.attach (new Widgets.LLabel.markup ("<b>"+
                            _("Oops! gomovie can't play this file!")+"</b>"), 1, 0, 1, 1);
                        grid.attach (new Widgets.LLabel (e.message), 1, 1, 1, 2);
                        welcome.show_all ();
                        clutter.hide ();

                        ((Gtk.Box)dlg.get_content_area ()).add (grid);
                        dlg.show_all ();
                        dlg.run ();
                        dlg.destroy ();
                        break;
                    case Gst.MessageType.ELEMENT:
                        if (msg.get_structure () != null &&
                            Gst.is_missing_plugin_message (msg)) {
                            this.canvas.get_pipeline ().set_state (Gst.State.NULL);
                            debug ("Missing plugin\n");
                            this.error = true;

                            this.set_keep_above (false);
                            clutter.hide ();
                            welcome.show ();

                            var detail = Gst.missing_plugin_message_get_description (msg);
                            var dlg = new Gtk.Dialog.with_buttons ("Missing plugin", this,
                                Gtk.DialogFlags.MODAL);
                            var grid = new Gtk.Grid ();
                            var err  = new Gtk.Image.from_stock (Gtk.Stock.DIALOG_ERROR,
                                Gtk.IconSize.DIALOG);
                            var phrase = new Widgets.LLabel (_("Some media files need extra software to be played. gomovie can install this software automatically."));

                            err.margin_right = 12;
                            grid.margin = 12;
                            grid.attach (err, 0, 0, 1, 1);
                            grid.attach (new Widgets.LLabel.markup ("<b>"+
                                _("gomovie needs %s to play this file.").printf (detail)+"</b>"), 1, 0, 1, 1);
                            grid.attach (phrase, 1, 1, 1, 2);

                            dlg.add_button (_("Don't install"), 1);
                            dlg.add_button (_("Install")+" "+detail, 0);

                            (dlg.get_content_area () as Gtk.Container).add (grid);

                            dlg.show_all ();
                            if (dlg.run () == 0) {
                                var installer = Gst.missing_plugin_message_get_installer_detail (msg);
                                var context = new Gst.InstallPluginsContext ();
                                Gst.install_plugins_async ({installer}, context,
                                () => { //finished
                                    debug ("Finished plugin install\n");
                                    Gst.update_registry ();
                                    mainbox.remove (err);
                                    clutter.show ();
                                    welcome.hide ();
                                    this.toggle_play (true);
                                });
                            }
                            dlg.destroy ();
                        } else { //may be navigation command
                            var nav_msg = Gst.Navigation.message_get_type (msg);

                            if (nav_msg == Gst.NavigationMessageType.COMMANDS_CHANGED) {
                                var q = Gst.Navigation.query_new_commands ();
                                print ("Hello world\n");
                                this.canvas.get_pipeline ().query (q);

                                uint n = 0;
                                gst_navigation_query_parse_commands_length (q, out n);
                                print ("Length of navigation: %u\n", n);
                                for (var i=0;i<n;i++) {
                                    Gst.NavigationCommand cmd;
                                    gst_navigation_query_parse_commands_nth (q, 0, out cmd);
                                    debug ("Got command: %i", (int)cmd);
                                }
                            }
                        }
                        break;
                    default:
                        break;
                }
            });
            
            
            //media keys
            /*try {
                this.mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                this.mediakeys.MediaPlayerKeyPressed.connect ( (bus, app, key) => {
                    if (app != "gomovie")
                       return;
                    switch (key) {
                        case "Previous":
                            this.playlist.previous ();
                            break;
                        case "Next":
                            this.playlist.next ();
                            break;
                        case "Play":
                            this.toggle_play (!this.playing);
                            break;
                        default:
                            break;
                    }
                });
                this.mediakeys.GrabMediaPlayerKeys("gomovie", (uint32)0);
            } catch (Error e) {
                warning (e.message);
            }*/
            
            
            //shortcuts
            this.key_press_event.connect ( (e) => {
                switch (e.keyval) {
                    case Gdk.Key.p:
                    case Gdk.Key.space:
                        this.toggle_play (!this.playing);
                        break;
                    case Gdk.Key.Escape:
                        if (this.fullscreened)
                            this.toggle_fullscreen ();
                        else
                            this.destroy ();
                        break;
                    case Gdk.Key.o:
                        this.run_open (0);
                        break;
                    case Gdk.Key.f:
                    case Gdk.Key.F11:
                        this.toggle_fullscreen ();
                        break;
                    case Gdk.Key.q:
                        this.destroy ();
                        break;
                    case Gdk.Key.Left:
                        if ((this.canvas.progress - 0.05) < 0)
                            this.canvas.progress = 0.0;
                        else
                            this.canvas.progress -= 0.05;
                        break;
                    case Gdk.Key.Right:
                        this.canvas.progress += 0.05;
                        break;
                    default:
                        break;
                }
                return true;
            });

            //end
            this.canvas.eos.connect ( () => {
                this.reached_end = true;
                this.toggle_play (false);
                this.playlist.next ();
            });
            
            

            //slider
            this.controls.slider.seeked.connect ( (v) => {
                debug ("Seeked to %f", v);
                canvas.progress = v;
            });
            canvas.notify["progress"].connect ( () => {
                this.controls.slider.progress = this.canvas.progress;

                this.controls.current.text = seconds_to_time (
                    (int)(this.controls.slider.progress * this.canvas.duration));
                this.controls.remaining.text = "-" + seconds_to_time ((int)(canvas.duration -
                    this.controls.slider.progress * this.canvas.duration));
            });
            canvas.notify["buffer_fill"].connect ( () => {
                this.controls.slider.buffered = this.canvas.buffer_fill;
            });

            /*slide controls back in*/
            this.motion_notify_event.connect ( () => {
                this.controls.hidden = false;
                if (this.fullscreened)
                    this.panel.hidden = false;
                if (!this.controls.slider.mouse_grabbed)
                    this.stage.cursor_visible = true;
                Gst.State state;
                canvas.get_pipeline ().get_state (out state, null, 0);
                if (state == Gst.State.PLAYING && !this.tagview.expanded && !this.controls.hovered){
                    this.toggle_timeout (true);
                }else {
                    this.toggle_timeout (false);
                }
                return false;
            });
            
            
            /*hide controls when mouse leaves window*/
            this.leave_notify_event.connect ( (e) => {
                if (!this.tagview.expanded && this.playing && !this.moving_action)
                    this.controls.hidden = true;
                return true;
            });
            
            

            /*open location popover*/
            this.controls.open.clicked.connect ( () => {
                var has_been_stopped = this.canvas.playing;

                this.toggle_play (false);
                this.toggle_timeout (false);

                if (!this.has_dvd) { //just one source, so open that one
                    Timeout.add (300, () => {
                        //this.toggle_play (false);
                        //this.toggle_timeout (false);
                        this.run_open (0);
                        return false;
                    });
                    return;
                }

                var pop = new Granite.Widgets.PopOver ();
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                ((Gtk.Box)pop.get_content_area ()).add (box);

                var fil   = new Gtk.Button.with_label (_("Add from Harddrive"));
                fil.image = new Gtk.Image.from_icon_name ("document-open", Gtk.IconSize.DIALOG);
                var dvd   = new Gtk.Button.with_label (_("Play a DVD"));
                dvd.image = new Gtk.Image.from_icon_name ("media-cdrom", Gtk.IconSize.DIALOG);
                var net   = new Gtk.Button.with_label (_("Network File"));
                net.image = new Gtk.Image.from_icon_name ("internet-web-browser", Gtk.IconSize.DIALOG);

                fil.clicked.connect ( () => {
                    pop.destroy ();
                    run_open (0);
                });
                dvd.clicked.connect ( () => {
                    run_open (2);
                    pop.destroy ();
                });
                net.clicked.connect ( () => {
                    var entry = new Gtk.Entry ();
                    entry.secondary_icon_stock = Gtk.Stock.OPEN;
                    entry.icon_release.connect ( (pos, e) => {
                        open_file (entry.text);
                        canvas.get_pipeline ().set_state (Gst.State.PLAYING);
                        pop.destroy ();
                    });
                    box.remove (net);
                    box.reorder_child (entry, 2);
                    entry.show ();
                });

                box.pack_start (fil);
                if (this.has_dvd)
                    box.pack_start (dvd);
                //box.pack_start (net); uri temporary dropped

                /*temporary until popover closing gets fixed*/
                var canc = new Gtk.Button.from_stock (Gtk.Stock.CANCEL);
                box.pack_start (canc);
                canc.clicked.connect ( () => {
                    pop.destroy ();
                });

                int x_r, y_r;
                this.get_window ().get_origin (out x_r, out y_r);

                pop.move_to_coords ((int)(x_r + this.stage.width - 50),
                    (int)(y_r + this.stage.height - CONTROLS_HEIGHT));

                pop.show_all ();

                Timeout.add (300, () => { //for some reason this doesn't cause a crash :)
                    pop.present ();
                    pop.run ();
                    pop.destroy ();
                    this.toggle_timeout (true);
                    if (has_been_stopped)
                        this.toggle_play (true);
                    return false;
                });
            });
            
            
            /*play pause*/
            this.controls.play.clicked.connect  ( () => {toggle_play (!this.playing);});

            /*unfullscreen*/
            this.panel.exit.clicked.connect (toggle_fullscreen);

            /*volume*/
            this.panel.vol.value_changed.connect ( (value) => {
                this.canvas.audio_volume = value;
            });
            this.panel.vol.value = 1.0;
            this.canvas.audio_volume = 1.0;

            this.controls.view.clicked.connect ( () => {
                if (!controls.showing_view) {
                    tagview.expand ();
                    controls.view.set_icon ("pane-hide-symbolic", Gtk.Stock.GO_FORWARD, "go-next-symbolic");
                    controls.showing_view = true;
                } else {
                    tagview.collapse ();
                    controls.view.set_icon ("pane-show-symbolic", Gtk.Stock.GO_BACK,
                        "go-previous-symbolic");
                    controls.showing_view = false;
                }
            });
            
            
            //fullscreen on maximize
            this.window_state_event.connect ( (e) => {
                if (!((e.window.get_state () & Gdk.WindowState.MAXIMIZED) == 0) && !this.fullscreened){
                    this.fullscreen ();
                    this.fullscreened = true;
                    this.panel.toggle (true);
                    return true;
                }
                return false;
            });
            
            

            //positioning
            int old_h=0;
            int old_w=0;
            this.size_allocate.connect ( () => {
                if (this.get_allocated_width () != old_w ||
                    this.get_allocated_height () != old_h) {
                    if (this.current_file != null)
                        this.place ();
                    old_w = this.get_allocated_width  ();
                    old_h = this.get_allocated_height ();
                }
                return;
            });
            
            

            /*moving the window by drag, fullscreen for dbl-click*/
            bool moving = false;
            this.canvas.button_press_event.connect ( (e) => {
                if (e.click_count > 1) {
                    toggle_fullscreen ();
                    return true;
                } else {
                    moving = true;
                    return true;
                }
            });
            
            
            clutter.motion_notify_event.connect ( (e) => {
                if (moving && settings.move_window) {
                    moving = false;
                    this.begin_move_drag (1,
                        (int)e.x_root, (int)e.y_root, e.time);

                    this.moving_action = true;

                    return true;
                }
                return false;
            });
            this.canvas.button_release_event.connect ( (e) => {
                moving = false;
                return false;
            });
            
            
            this.focus_in_event.connect (() => moving_action = false );

            /*DnD*/
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (this,
                Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.MOVE);
            this.drag_data_received.connect ( (ctx, x, y, sel, info, time) => {
                for (var i=1;i<sel.get_uris ().length; i++)
                    this.playlist.add_item (File.new_for_uri (sel.get_uris ()[i]));
                this.open_file (sel.get_uris ()[0]);
                welcome.hide ();
                clutter.show_all ();
            });
            
            

            //save position in video when not finished playing
            this.destroy.connect ( () => {
                if (this.current_file == null || this.canvas.uri.has_prefix ("dvd://"))
                    return;
                if (!reached_end) {
                    for (var i=0;i<this.last_played_videos.length ();i+=2){
                        if (this.current_file.get_uri () == this.last_played_videos.nth_data (i)){
                            this.last_played_videos.nth (i+1).data = this.canvas.progress.to_string ();
                            this.save_last_played_videos ();
                            return;
                        }
                    }
                    //not in list yet, insert at start
                    this.last_played_videos.insert (this.current_file.get_uri (), 0);
                    this.last_played_videos.insert (this.canvas.progress.to_string (), 1);
                    if (this.last_played_videos.length () > 10) {
                        this.last_played_videos.delete_link (this.last_played_videos.nth (10));
                        this.last_played_videos.delete_link (this.last_played_videos.nth (11));
                    }
                    this.save_last_played_videos ();
                }
            });
	    }

        //the application was requested to open some files
        public void open (File [] files, string hint) {
            for (var i=1;i<files.length;i++)
                this.playlist.add_item (files[i]);
            this.open_file (files[0].get_path ());
            this.welcome.hide ();
            this.clutter.show_all ();
        }
	    
        private inline void save_last_played_videos () {
            string res = "";
            for (var i=0;i<this.last_played_videos.length () - 1;i++) {
                res += this.last_played_videos.nth_data (i) + ",";
            }
            res += this.last_played_videos.nth_data (this.last_played_videos.length () - 1);
            settings.last_played_videos = res;
        }

        public void run_open (int type) { //0=file, 2=dvd
            if (type == 0) {
                var file = new Gtk.FileChooserDialog (_("Open"), this, Gtk.FileChooserAction.OPEN,
                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                    Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
                file.select_multiple = true;

                var all_files_filter = new Gtk.FileFilter ();
                all_files_filter.set_filter_name (_("All files"));
                all_files_filter.add_pattern ("*");

                var video_filter = new Gtk.FileFilter ();
                video_filter.set_filter_name (_("Video files"));
                video_filter.add_mime_type ("video/"+ "*");

                file.add_filter (video_filter);
                file.add_filter (all_files_filter);

                file.set_current_folder (settings.last_folder);
                if (file.run () == Gtk.ResponseType.ACCEPT) {
                    welcome.hide ();
                    clutter.show_all ();
                    for (var i=1;i<file.get_files ().length ();i++) {
                        this.playlist.add_item (file.get_files ().nth_data (i));
                    }
                    open_file (file.get_uri ());
                    settings.last_folder = file.get_current_folder ();
                }
                file.destroy ();
            }else if (type == 2){
                open_file ("dvd://", true);
                canvas.playing = true;
                welcome.hide ();
                clutter.show_all ();
            }
        }

        private void toggle_play (bool start) {
            if (!start) {
                this.controls.show_play_button (true);
                canvas.playing = false;
                Source.remove (this.hiding_timer);
                this.set_screensaver (true);
                this.playing = false;

                this.controls.hidden = false;
                if (this.fullscreened)
                    this.panel.hidden = false;

                this.set_keep_above (false);
            } else {
                if (this.reached_end) {
                    canvas.progress = 0.0;
                    this.reached_end = false;
                }
                canvas.set_playing (true);
                this.controls.show_play_button (false);
                this.place ();

                toggle_timeout (true);

                this.set_screensaver (false);
                this.playing = true;

                if (settings.stay_on_top)
                    this.set_keep_above (true);
            }
        }
        
	    
        private void toggle_timeout (bool enable) {
            if (this.hiding_timer != 0)
                Source.remove (this.hiding_timer);
            if (enable) {
                this.hiding_timer = GLib.Timeout.add (2000, () => {
                    if (this.moving_action)
                    	return false;

                    this.stage.cursor_visible = false;
                    this.controls.hidden = true;
                    this.panel.hidden = true;
                    return false;
                });
            }
        }

        private void toggle_fullscreen () {
            if (fullscreened) {
                this.unmaximize ();
                this.unfullscreen ();
                this.fullscreened = false;
                this.panel.toggle (false);
                this.place ();
            } else {
                this.fullscreen ();
                this.fullscreened = true;
                this.panel.toggle (true);

                stage.height = Gdk.Screen.get_default ().height ();
                this.place ();
            }
        }

        internal void open_file (string filename, bool dont_modify=false) {
            this.error = false; //reset error
            this.current_file = File.new_for_commandline_arg (filename);

            if (this.current_file.query_file_type (0) == FileType.DIRECTORY) {
                gomovie.recurse_over_dir (this.current_file, (file_ret) => {
                	this.playlist.add_item (file_ret);
                });
                this.current_file = this.playlist.get_first_item ();
            }
            else {
                this.playlist.add_item (this.current_file);
            }
            play_file ();
        }
	    public void play_file () {
            this.reached_end = false;
            debug ("Opening %s", this.current_file.get_uri ());
            var uri = this.current_file.get_uri ();
            canvas.uri = uri;
            canvas.audio_volume = 1.0;
            this.controls.slider.preview.uri = uri;
            this.controls.slider.preview.audio_volume = 0.0;

            //this.title = get_title (current_file.get_basename ());
            if (settings.show_details)
                tagview.get_tags (uri, true);

            if (!settings.playback_wait)
                this.toggle_play (true);
            this.place (true);

            if (settings.resume_videos) {
                int i;
                for (i=0;i<this.last_played_videos.length () && i!=-1;i+=2) {
                    if (this.current_file.get_uri () == this.last_played_videos.nth_data (i))
                        break;
                    if (i == this.last_played_videos.length () - 1)
                        i = -1;
                }
                if (i != -1 && this.last_played_videos.nth_data (i + 1) != null) {
                    this.canvas.progress = double.parse (this.last_played_videos.nth_data (i + 1));
                    debug ("Resuming video from "+this.last_played_videos.nth_data (i + 1));
                }
            }

            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            //disable subtitles by default
            dynamic Gst.Element pipe = this.canvas.get_pipeline ();
            int flags;
            pipe.get ("flags", out flags);
            flags &= ~SUBTITLES_FLAG;
            flags |= DOWNLOAD_FLAG;
            pipe.set ("flags", flags, "current-text", -1);

            //subtitles/audio tracks
            this.tagview.setup_setup ("text");
            this.tagview.setup_setup ("audio");
        }
        
	    private void place (bool resize_window = false) {
            this.tagview.x        = (this.tagview.expanded)?
                stage.width - this.tagview.width:
                stage.width;

            canvas.get_base_size (out video_w, out video_h);
            //aspect ratio handling
            if (!this.error) {
                var aspect = (stage.width/video_w < stage.height/video_h)?   stage.width/video_w:
                                                                            stage.height/video_h;
                this.canvas.width  = video_w * aspect;
                this.canvas.height = video_h * aspect;
                this.canvas.x      = (stage.width  - this.canvas.width)  / 2;
                this.canvas.y      = (stage.height - this.canvas.height) / 2;

                if (resize_window && video_w > 50 && video_h > 50)
                    fit_window ();
            }

            this.controls.width = stage.width;
            if (this.controls.get_animation () != null)
            	this.controls.detach_animation ();
            this.controls.y = (this.controls.hidden)?stage.height:stage.height - controls.height;

            if (this.fullscreened) {
                this.controls.y = (this.controls.hidden)?Gdk.Screen.get_default ().height ():
                                       Gdk.Screen.get_default ().height () - CONTROLS_HEIGHT;
            } else if (stage.height - CONTROLS_HEIGHT > 50)
                this.controls.y = stage.height - CONTROLS_HEIGHT;
        }

	    public void set_screensaver (bool enable) {
            var xid = (ulong)Gdk.X11Window.get_xid (this.get_window ());
            try {
                if (enable) {
                    Process.spawn_command_line_sync (
                        "xdg-screensaver resume "+xid.to_string ());
                } else {
                    Process.spawn_command_line_sync (
                        "xdg-screensaver suspend "+xid.to_string ());
                }
            } catch (Error e) {warning (e.message);}
        }
        
        private void fit_window () {
            var ung = Gdk.Geometry (); // unlock
            ung.min_aspect = 0.0;
            ung.max_aspect = 99999999.0;
            this.set_geometry_hints (this, ung, Gdk.WindowHints.ASPECT);

            if (Gdk.Screen.get_default ().width ()  > this.video_w &&
                Gdk.Screen.get_default ().height () > this.video_h) {
                this.resize (
                    (int)this.video_w, (int)this.video_h);
            } else {
                this.resize (
                    (int)(Gdk.Screen.get_default ().width () * 0.9),
                    (int)(Gdk.Screen.get_default ().height () * 0.9));
            }

            if (settings.keep_aspect) {
                var g = Gdk.Geometry (); // lock
                g.min_aspect = g.max_aspect = this.video_w / this.video_h;
                this.set_geometry_hints (this, g, Gdk.WindowHints.ASPECT);
            }
        }
	}
}

public static int main (string[] args) {
	X.init_threads ();
    //Gst.init (ref args);
    Gtk.init (ref args);
	var err = GtkClutter.init (ref args);
    if (err != Clutter.InitError.SUCCESS) {
        error ("Could not initalize clutter! "+err.to_string ());
    }
    ClutterGst.init (ref args);
    var sample = new gomovie.App ();
    sample.show_all ();

    Gtk.main ();

    return 0;
}