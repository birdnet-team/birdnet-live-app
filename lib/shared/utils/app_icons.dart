// =============================================================================
// App Icons — Centralized icon mapping for third-party icon packages
// =============================================================================
//
// This file isolates icon selections that come from external icon packages.
// Keeping a small app-level mapping lets us swap icon packages safely without
// touching many feature files.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

abstract final class AppIcons {
  // Material icon mappings used across the project.
  static const IconData acUnit = Symbols.ac_unit;
  static const IconData add = Symbols.add;
  static const IconData addCircleOutline = Symbols.add_circle;
  static const IconData addRounded = Symbols.add_rounded;
  static const IconData air = Symbols.air;
  static const IconData airRounded = Symbols.air_rounded;
  static const IconData arrowBackRounded = Symbols.arrow_back_rounded;
  static const IconData arrowDownward = Symbols.arrow_downward;
  static const IconData arrowDropUpRounded = Symbols.arrow_drop_up_rounded;
  // Keep style-explicit names when outlined and rounded variants are both used.
  static const IconData audioFileOutlined = Symbols.audio_file;
  static const IconData audioFileRounded = Symbols.audio_file_rounded;
  static const IconData barChart = Symbols.bar_chart;
  static const IconData batteryAlert = Symbols.battery_alert;
  static const IconData batteryChargingFull = Symbols.battery_charging_full;
  static const IconData batterySaverRounded = Symbols.battery_saver_rounded;
  static const IconData bluetoothAudio = Symbols.bluetooth_audio;
  static const IconData bookmarkAdded = Symbols.bookmark_added;
  static const IconData brokenImage = Symbols.broken_image;
  static const IconData calendarToday = Symbols.calendar_today;
  static const IconData calendarTodayRounded = Symbols.calendar_today_rounded;
  static const IconData campaign = Symbols.campaign;
  static const IconData category = Symbols.category;
  static const IconData check = Symbols.check;
  static const IconData checkCircle = Symbols.check_circle;
  static const IconData checkCircleOutline = Symbols.check_circle;
  static const IconData checkCircleRounded = Symbols.check_circle_rounded;
  static const IconData checkRounded = Symbols.check_rounded;
  static const IconData chevronRight = Symbols.chevron_right;
  static const IconData clear = Symbols.clear;
  static const IconData clearRounded = Symbols.clear_rounded;
  static const IconData close = Symbols.close;
  static const IconData closeRounded = Symbols.close_rounded;
  static const IconData cloudOff = Symbols.cloud_off;
  static const IconData cloud = Symbols.cloud;
  static const IconData cloudy = Symbols.cloudy;
  static const IconData code = Symbols.code;
  static const IconData contentCut = Symbols.content_cut;
  static const IconData deleteOutline = Symbols.delete;
  static const IconData deleteOutlineRounded = Symbols.delete_outline_rounded;
  static const IconData deleteSweep = Symbols.delete_sweep;
  static const IconData directionsWalkRounded = Symbols.directions_walk_rounded;
  static const IconData detections = Symbols.list_alt_rounded;
  static const IconData downloadForOffline = Symbols.download_for_offline;
  static const IconData edit = Symbols.edit;
  static const IconData editLocationAlt = Symbols.edit_location_alt;
  static const IconData editNote = Symbols.edit_note;
  static const IconData errorOutline = Symbols.error_outline;
  static const IconData errorOutlineRounded = Symbols.error_outline_rounded;
  static const IconData expandLess = Symbols.expand_less;
  static const IconData expandMore = Symbols.expand_more;
  static const IconData fiberManualRecord = Symbols.fiber_manual_record;
  static const IconData fiberManualRecordRounded =
      Symbols.fiber_manual_record_rounded;
  static const IconData filterAltRounded = Symbols.filter_alt_rounded;
  static const IconData filterList = Symbols.filter_list;
  static const IconData flagFilled = Icons.flag;
  static const IconData flagRounded = Symbols.flag_rounded;
  static const IconData foggy = Symbols.foggy;
  static const IconData formatListNumberedRounded =
      Symbols.format_list_numbered_rounded;
  static const IconData fullscreen = Symbols.fullscreen;
  static const IconData gavel = Symbols.gavel;
  static const IconData gavelRounded = Symbols.gavel_rounded;
  static const IconData grain = Symbols.grain;
  static const IconData graphicEq = Symbols.graphic_eq;
  static const IconData graphicEqRounded = Symbols.graphic_eq_rounded;
  static const IconData gridViewRounded = Symbols.grid_view_rounded;
  static const IconData hearing = Symbols.hearing;
  static const IconData helpOutline = Symbols.help;
  static const IconData helpOutlineRounded = Symbols.help_outline_rounded;
  static const IconData hourglassTopRounded = Symbols.hourglass_top_rounded;
  static const IconData imageNotSupported = Symbols.image_not_supported;
  static const IconData infoOutline = Symbols.info;
  static const IconData landscapeRounded = Symbols.landscape_rounded;
  static const IconData libraryBooks = Symbols.library_books;
  static const IconData libraryMusic = Symbols.library_music;
  static const IconData lightbulbOutline = Symbols.lightbulb;
  static const IconData listAlt = Symbols.list_alt;
  static const IconData listAltRounded = Symbols.list_alt_rounded;
  static const IconData locationOff = Symbols.location_off;
  static const IconData locationOffRounded = Symbols.location_off_rounded;
  static const IconData locationOn = Symbols.location_on;
  static const IconData locationOnFilled = Icons.location_on;
  static const IconData locationOnRounded = Symbols.location_on_rounded;
  static const IconData lockOutline = Symbols.lock;
  static const IconData map = Symbols.location_on;
  static const IconData mapSheet = Symbols.map;
  static const IconData memory = Symbols.memory;
  static const IconData menuBook = Symbols.menu_book;
  static const IconData mic = Symbols.mic;
  static const IconData micExternalOnRounded = Symbols.mic_external_on_rounded;
  static const IconData micNone = Symbols.mic_none;
  // Kept for style clarity alongside mic/micRounded/micOff variants.
  static const IconData micNoneOutlined = Symbols.mic_none;
  static const IconData micOff = Symbols.mic_off;
  static const IconData micRounded = Symbols.mic_rounded;
  static const IconData moreVert = Symbols.more_vert;
  static const IconData musicNote = Symbols.music_note;
  static const IconData myLocation = Symbols.my_location;
  static const IconData noteAdd = Symbols.note_add;
  // Kept as explicit style variant for notification status icon usage.
  static const IconData notificationsActiveOutlined =
      Symbols.notifications_active;
  static const IconData notificationsActiveRounded =
      Symbols.notifications_active_rounded;
  static const IconData openInNew = Symbols.open_in_new;
  static const IconData pause = Symbols.pause;
  static const IconData pauseRounded = Symbols.pause_rounded;
  static const IconData partlyCloudyDay = Symbols.partly_cloudy_day;
  static const IconData percent = Symbols.percent;
  static const IconData personOutline = Symbols.person;
  static const IconData personPinCircleRounded =
      Symbols.person_pin_circle_rounded;
  static const IconData personRounded = Symbols.person_rounded;
  static const IconData playArrow = Symbols.play_arrow;
  static const IconData playArrowRounded = Symbols.play_arrow_rounded;
  static const IconData playCircleOutline = Symbols.play_circle;
  static const IconData privacyTip = Symbols.privacy_tip;
  static const IconData public = Symbols.public;
  static const IconData publicOffRounded = Symbols.public_off_rounded;
  static const IconData radioButtonUnchecked = Symbols.radio_button_unchecked;
  static const IconData redo = Symbols.redo;
  static const IconData refresh = Symbols.refresh;
  static const IconData repeatRounded = Symbols.repeat_rounded;
  static const IconData reportProblem = Symbols.report_problem;
  static const IconData rainy = Symbols.rainy;
  static const IconData rainyLight = Symbols.rainy_light;
  // Kept as outlined to pair with routeRounded where style is intentional.
  static const IconData routeOutlined = Symbols.route;
  static const IconData routeRounded = Symbols.route_rounded;
  static const IconData save = Symbols.save;
  static const IconData saveAlt = Symbols.save_alt;
  static const IconData saveRounded = Symbols.save_rounded;
  static const IconData schedule = Symbols.schedule;
  static const IconData scheduleRounded = Symbols.schedule_rounded;
  // Kept as outlined to pair with scienceRounded.
  static const IconData scienceOutlined = Symbols.science;
  static const IconData scienceRounded = Symbols.science_rounded;
  static const IconData sdStorage = Symbols.sd_storage;
  static const IconData search = Symbols.search;
  static const IconData searchOff = Symbols.search_off;
  static const IconData searchRounded = Symbols.search_rounded;
  static const IconData securityRounded = Symbols.security_rounded;
  static const IconData send = Symbols.send;
  static const IconData selectAll = Symbols.select_all;
  static const IconData deselect = Symbols.deselect;
  static const IconData share = Symbols.share;
  static const IconData shortText = Symbols.short_text;
  static const IconData skipNextRounded = Symbols.skip_next_rounded;
  static const IconData skipPreviousRounded = Symbols.skip_previous_rounded;
  static const IconData sort = Symbols.sort;
  static const IconData species = Symbols.graphic_eq;
  static const IconData speciesFallback = brokenImage;
  static const IconData speedRounded = Symbols.speed_rounded;
  static const IconData stickyNote2 = Symbols.sticky_note_2;
  static const IconData stop = Icons.stop;
  static const IconData stopCircle = Icons.stop_circle;
  static const IconData stopRounded = Icons.stop_rounded;
  static const IconData storage = Symbols.storage;
  static const IconData straighten = Symbols.straighten;
  static const IconData summaryChart = Symbols.bar_chart;
  static const IconData swapHoriz = Symbols.swap_horiz;
  static const IconData thunderstorm = Symbols.thunderstorm;
  static const IconData timerOff = Symbols.timer_off;
  // Kept as outlined to pair with timerRounded.
  static const IconData timerOutlined = Symbols.timer;
  static const IconData timerRounded = Symbols.timer_rounded;
  static const IconData touchApp = Symbols.touch_app;
  static const IconData travelExplore = Symbols.travel_explore;
  static const IconData tune = Symbols.tune;
  static const IconData tuneRounded = Symbols.tune_rounded;
  static const IconData undo = Symbols.undo;
  static const IconData uploadFileRounded = Symbols.upload_file_rounded;
  static const IconData verifiedRounded = Symbols.verified_rounded;
  static const IconData vibrationRounded = Symbols.vibration_rounded;
  static const IconData volunteerActivism = Symbols.volunteer_activism;
  static const IconData volumeDown = Symbols.volume_down;
  static const IconData volumeMuteRounded = Symbols.volume_mute_rounded;
  static const IconData volumeOffRounded = Symbols.volume_off_rounded;
  // Kept as outlined to pair with volumeUpRounded.
  static const IconData volumeUpOutlined = Symbols.volume_up;
  static const IconData volumeUpRounded = Symbols.volume_up_rounded;
  static const IconData warningAmberRounded = Symbols.warning_amber_rounded;
  static const IconData waterDrop = Symbols.water_drop;
  static const IconData wbCloudy = Symbols.wb_cloudy;
  static const IconData wbSunny = Symbols.wb_sunny;
  static const IconData wbTwilightRounded = Symbols.wb_twilight_rounded;
  static const IconData weatherSnowy = Symbols.weather_snowy;
}
