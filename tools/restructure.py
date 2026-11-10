#!/usr/bin/env python3
"""One-shot repo restructure: moves files per the map and rewrites imports."""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

MOVES = {
    "lib/config/app_constants.dart": "lib/core/app_constants.dart",
    "lib/config/app_routes.dart": "lib/core/app_routes.dart",
    "lib/config/app_theme.dart": "lib/core/app_theme.dart",
    "lib/firebase_options.dart": "lib/core/firebase_options.dart",
    "lib/services/campus_time.dart": "lib/core/campus_time.dart",
    "lib/models/user_model.dart": "lib/core/user_model.dart",
    "lib/models/room_model.dart": "lib/core/room_model.dart",

    "lib/screens/splash_screen.dart": "lib/features/auth/screens/splash_screen.dart",
    "lib/screens/auth/login_screen.dart": "lib/features/auth/screens/login_screen.dart",
    "lib/screens/auth/register_screen.dart": "lib/features/auth/screens/register_screen.dart",
    "lib/screens/auth/account_access_screen.dart": "lib/features/auth/screens/account_access_screen.dart",
    "lib/screens/auth/restricted_account_screen.dart": "lib/features/auth/screens/restricted_account_screen.dart",
    "lib/services/auth_service.dart": "lib/features/auth/services/auth_service.dart",
    "lib/services/account_access.dart": "lib/features/auth/services/account_access.dart",
    "lib/services/device_id_service.dart": "lib/features/auth/services/device_id_service.dart",
    "lib/services/device_change_service.dart": "lib/features/auth/services/device_change_service.dart",
    "lib/widgets/account_profile_panel.dart": "lib/features/auth/widgets/account_profile_panel.dart",
    "lib/widgets/gradient_button.dart": "lib/features/auth/widgets/gradient_button.dart",
    "lib/screens/auth/account_access_screen.dart": "lib/features/auth/screens/account_access_screen.dart",

    "lib/models/location_model.dart": "lib/features/presence/models/location_model.dart",
    "lib/services/presence_service.dart": "lib/features/presence/services/presence_service.dart",
    "lib/services/location_policy.dart": "lib/features/presence/services/location_policy.dart",
    "lib/services/forecast_service.dart": "lib/features/presence/services/forecast_service.dart",
    "lib/services/availability_predictor.dart": "lib/features/presence/services/availability_predictor.dart",
    "lib/providers/presence_provider.dart": "lib/features/presence/providers/presence_provider.dart",
    "lib/providers/ble_provider.dart": "lib/features/presence/providers/ble_provider.dart",
    "lib/widgets/sharing_settings.dart": "lib/features/presence/widgets/sharing_settings.dart",

    "lib/screens/student/ai_chat_screen.dart": "lib/features/assistant/screens/ai_chat_screen.dart",
    "lib/models/chat_message.dart": "lib/features/assistant/models/chat_message.dart",
    "lib/services/assistant/faculty_assistant.dart": "lib/features/assistant/services/faculty_assistant.dart",
    "lib/services/assistant/firestore_faculty_repository.dart": "lib/features/assistant/services/firestore_faculty_repository.dart",
    "lib/widgets/chat_bubble.dart": "lib/features/assistant/widgets/chat_bubble.dart",

    "lib/models/attendance_model.dart": "lib/features/attendance/models/attendance_model.dart",
    "lib/models/attendance_session_model.dart": "lib/features/attendance/models/attendance_session_model.dart",
    "lib/models/schedule_model.dart": "lib/features/attendance/models/schedule_model.dart",
    "lib/services/attendance_service.dart": "lib/features/attendance/services/attendance_service.dart",
    "lib/services/attendance_session_service.dart": "lib/features/attendance/services/attendance_session_service.dart",
    "lib/services/attendance_outbox.dart": "lib/features/attendance/services/attendance_outbox.dart",
    "lib/services/attendance_dwell_tracker.dart": "lib/features/attendance/services/attendance_dwell_tracker.dart",
    "lib/services/beacon_stability.dart": "lib/features/attendance/services/beacon_stability.dart",
    "lib/services/ble_scanner_service.dart": "lib/features/attendance/services/ble_scanner_service.dart",
    "lib/providers/attendance_provider.dart": "lib/features/attendance/providers/attendance_provider.dart",
    "lib/providers/attendance_sessions_provider.dart": "lib/features/attendance/providers/attendance_sessions_provider.dart",
    "lib/providers/campus_clock_provider.dart": "lib/features/attendance/providers/campus_clock_provider.dart",
    "lib/screens/student/student_dashboard.dart": "lib/features/attendance/screens/student/student_dashboard.dart",
    "lib/screens/student/attendance_scan_screen.dart": "lib/features/attendance/screens/student/attendance_scan_screen.dart",
    "lib/screens/student/tabs/student_home_tab.dart": "lib/features/attendance/screens/student/tabs/student_home_tab.dart",
    "lib/screens/student/tabs/student_attendance_tab.dart": "lib/features/attendance/screens/student/tabs/student_attendance_tab.dart",
    "lib/screens/student/tabs/student_profile_tab.dart": "lib/features/attendance/screens/student/tabs/student_profile_tab.dart",
    "lib/widgets/attendance_card.dart": "lib/features/attendance/widgets/attendance_card.dart",
    "lib/widgets/attendance_session_card.dart": "lib/features/attendance/widgets/attendance_session_card.dart",
    "lib/widgets/class_picker_sheet.dart": "lib/features/attendance/widgets/class_picker_sheet.dart",
    "lib/widgets/join_class_dialog.dart": "lib/features/attendance/widgets/join_class_dialog.dart",
    "lib/widgets/dwell_progress_ring.dart": "lib/features/attendance/widgets/dwell_progress_ring.dart",
    "lib/widgets/attendance_scan_widgets.dart": "lib/features/attendance/widgets/attendance_scan_widgets.dart",
    "lib/widgets/attendance_export_button.dart": "lib/features/attendance/widgets/attendance_export_button.dart",
    "lib/widgets/session_enrollment_sheet.dart": "lib/features/attendance/widgets/session_enrollment_sheet.dart",

    "lib/screens/faculty/faculty_dashboard.dart": "lib/features/faculty/screens/faculty_dashboard.dart",
    "lib/screens/faculty/tabs/faculty_home_tab.dart": "lib/features/faculty/screens/faculty_home_tab.dart",
    "lib/screens/faculty/tabs/faculty_attendance_tab.dart": "lib/features/faculty/screens/faculty_attendance_tab.dart",
    "lib/screens/faculty/tabs/faculty_profile_tab.dart": "lib/features/faculty/screens/faculty_profile_tab.dart",
    "lib/screens/faculty/attendance_roster_screen.dart": "lib/features/faculty/screens/attendance_roster_screen.dart",

    "lib/screens/faculty/tabs/faculty_schedule_tab.dart": "lib/features/schedule/screens/faculty_schedule_tab.dart",
    "lib/widgets/schedule_dialogs.dart": "lib/features/schedule/widgets/schedule_dialogs.dart",

    "lib/providers/auth_provider.dart": "lib/shared/providers/auth_provider.dart",
    "lib/models/presence_model.dart": "lib/features/presence/models/presence_model.dart",
    "lib/services/firestore_service.dart": "lib/shared/services/firestore_service.dart",
    "lib/widgets/glass_card.dart": "lib/shared/widgets/glass_card.dart",
    "lib/widgets/app_navigation.dart": "lib/shared/widgets/app_navigation.dart",
    "lib/widgets/ble_readiness_banner.dart": "lib/shared/widgets/ble_readiness_banner.dart",
}

class Mover:
    def __init__(self, root, moves):
        self.root, self.moves = root, moves
        self.map = moves  # old_rel -> new_rel

    def track(self, rel):
        r = subprocess.run(
            ["git", "ls-files", "--error-unmatch", rel],
            cwd=self.root, capture_output=True)
        return r.returncode == 0

    def perform(self):
        for old, new in self.map.items():
            osrc, onew = os.path.join(self.root, old), os.path.join(self.root, new)
            if not os.path.exists(osrc):
                print(f"MISSING {old}")
                continue
            os.makedirs(os.path.dirname(onew), exist_ok=True)
            if self.track(old):
                subprocess.run(["git", "mv", old, new], cwd=self.root, check=True)
            else:
                os.rename(osrc, onew)
                print(f"plain mv (untracked): {old}")

    def relpath(self, frm_dir, to_file):
        rel = os.path.relpath(to_file, frm_dir).replace(os.sep, "/")
        return rel

    def rewrite(self):
        pat = re.compile(r"^(import|export|part)\s+(['\"])([^'\"]+)\2", re.M)
        inverse = {v: k for k, v in self.map.items()}
        def is_global(p):
            return p.startswith("dart:") or p.startswith("package:")
        pkg_prefix = "package:findmoser_app/"
        for base in ("lib", "test"):
            for dirpath, _, files in os.walk(os.path.join(self.root, base)):
                for name in files:
                    if not name.endswith(".dart"):
                        continue
                    fpath = os.path.join(dirpath, name)
                    rel_file = os.path.relpath(fpath, self.root).replace(os.sep, "/")
                    old_rel = inverse.get(rel_file, rel_file)
                    old_dir = os.path.dirname(os.path.join(self.root, old_rel))
                    new_dir = os.path.dirname(fpath)
                    is_test = rel_file.startswith("test/")
                    src = open(fpath).read()
                    out_lines = []
                    replaced = False
                    for lineno, line in enumerate(src.splitlines(keepends=True)):
                        m = pat.match(line)
                        if not m:
                            out_lines.append(line)
                            continue
                        kw, quote, p = m.group(1), m.group(2), m.group(3)
                        if p.startswith("dart:"):
                            out_lines.append(line)
                            continue
                        if p.startswith("package:"):
                            if p.startswith(pkg_prefix):
                                key = os.path.join(
                                    "lib", p[len(pkg_prefix):]
                                ).replace(os.sep, "/")
                                if key in self.map:
                                    newpkg = pkg_prefix + self.map[key][len("lib/"):]
                                    new_line = line.replace(p, newpkg, 1)
                                    out_lines.append(new_line)
                                    replaced = True
                                else:
                                    out_lines.append(line)
                            else:
                                out_lines.append(line)
                            continue
                        # relative import: resolve against the OLD importer dir
                        tgt = os.path.normpath(os.path.join(old_dir, p))
                        tgt_rel = os.path.relpath(tgt, self.root).replace(os.sep, "/")
                        if not os.path.exists(tgt) and tgt_rel not in self.map:
                            out_lines.append(line)
                            continue
                        final_rel = self.map.get(tgt_rel, tgt_rel)
                        if is_test:
                            if final_rel.startswith("lib/"):
                                newimp = pkg_prefix + final_rel[4:]
                            else:
                                newimp = self.relpath(dirpath, os.path.join(self.root, final_rel))
                        else:
                            newimp = self.relpath(new_dir, os.path.join(self.root, final_rel))
                        new_line = line.replace(p, newimp, 1)
                        if new_line != line:
                            replaced = True
                        out_lines.append(new_line)
                    mod = "".join(out_lines)
                    if replaced:
                        open(fpath, "w").write(mod)
                        print("rewrote", rel_file)

if __name__ == "__main__":
    m = Mover(ROOT, MOVES)
    m.perform()
    m.rewrite()
    print("done")
