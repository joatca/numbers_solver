/*
This file is part of Numbers Solver - solve the Numbers game used in several
long-running European game shows

Copyright (C) 2021 Fraser McCrossan

flax is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoPage extends StatelessWidget {
  static const url = 'https://apps.joat.me/page/numbers/';
  static const ppurl = 'https://apps.joat.me/page/privacy';
  static const copyyear = '2021';
  static const copyright = 'Fraser McCrossan';
  static const title = 'Numbers Game Solver';
  static const license =
      'This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('About'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          pad(title, theme.headline5),
          pad('Copyright ⓒ $copyyear $copyright', theme.bodyText2),
          pad(license, theme.bodyText1),
          Expanded(
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ButtonBar(
                    alignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                          onPressed: () {
                            _launchURL(url);
                          },
                          child: Text(
                            'App Page',
                          )),
                      TextButton(
                          onPressed: () {
                            _launchURL(ppurl);
                          },
                          child: Text(
                            'Privacy Policy',
                          )),
                    ],
                  ))),
        ],
      ),
    );
  }

  pad(String text, TextStyle style) {
    return Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          text,
          style: style,
        ));
  }

  _launchURL(String url) async {
    print("launching $url");
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
