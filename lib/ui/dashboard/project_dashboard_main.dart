import 'package:flutter/material.dart';
import 'package:geo_monitor/ui/dashboard/project_dashboard_mobile.dart';
import 'package:geo_monitor/ui/dashboard/project_dashboard_tablet_landscape.dart';
import 'package:geo_monitor/ui/dashboard/project_dashboard_tablet_portrait.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../../library/data/project.dart';

class ProjectDashboardMain extends StatelessWidget {
  const ProjectDashboardMain({Key? key, required this.project})
      : super(key: key);
  final Project project;

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout(
      mobile: ProjectDashboardMobile(
        project: project,
      ),
      tablet: OrientationLayoutBuilder(
        portrait: (context) {
          return ProjectDashboardTabletPortrait(
            project: project,
          );
        },
        landscape: (context) {
          return ProjectDashboardTabletLandscape(
            project: project,
          );
        },
      ),
    );
  }
}
