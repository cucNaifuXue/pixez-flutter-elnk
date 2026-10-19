/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:async';
import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/artwork_page_route.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/models/trend_tags.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/saucenao/sauce_nao_modal.dart';
import 'package:pixez/page/search/result_page.dart';
import 'package:pixez/page/search/search_bar.dart';
import 'package:pixez/page/search/search_tag_panel.dart';
import 'package:pixez/page/search/suggest/search_suggestion_page.dart';
import 'package:pixez/page/search/trend_tags_store.dart';
import 'package:pixez/page/webview/saucenao_webview_page.dart';
import 'package:pixez/utils/haptic_util.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  String editString = "";
  late TrendTagsStore _trendTagsStore;
  bool _loadingTags = true;
  bool _tagsFailed = false;
  late StreamSubscription<String> _topSubscription;

  @override
  void initState() {
    _trendTagsStore = TrendTagsStore();
    super.initState();
    tagHistoryStore.fetch();
    _refreshTags();
    _topSubscription = topStore.topStream.listen((event) {
      if (event == "400") {
        _openSearch();
      }
    });
  }

  void _openSearch() {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(pageBuilder: (_, __, ___) => SearchSuggestionPage()),
    );
  }

  @override
  void dispose() {
    _topSubscription.cancel();
    super.dispose();
  }

  Widget _buildFirstRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            child: Padding(
              child: Text(
                I18n.of(context).search,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30.0,
                  color: Theme.of(context).textTheme.titleLarge!.color,
                ),
              ),
              padding: EdgeInsets.only(left: 16.0, bottom: 10.0),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _refreshTags() async {
    final success = await _trendTagsStore.fetch();
    if (mounted) {
      setState(() {
        _loadingTags = false;
        _tagsFailed = !success;
      });
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Observer(
      builder: (_) {
        if (accountStore.now == null) {
          return Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: Text(I18n.of(context).search),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _openSearch,
                  ),
                ],
              ),
            ],
          );
        }
        return SafeArea(
          child: Column(
            children: [
              SearchBar(
                onSaucenao: () {
                  if (userSetting.useSaunceNaoWebview) {
                    Leader.push(context, SauncenaoWebview());
                  } else {
                    SauceNaoModal.show(context);
                  }
                },
              ),
              _buildFirstRow(context),
              Expanded(
                child: Observer(
                  builder: (_) {
                    final history = tagHistoryStore.tags
                        .where((tag) => tag.type == null || tag.type == 0)
                        .toList();
                    final tags = _trendTagsStore.trendTags;
                    return SearchTagPanel(
                      tagCount: tags.length,
                      historyCount: history.length,
                      isLoading: _loadingTags,
                      hasError: _tagsFailed,
                      onRefresh: _refreshTags,
                      onClearHistory: _clearHistory,
                      tagBuilder: (context, index) => _buildTag(tags[index]),
                      historyBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Center(
                          child: buildActionChip(history[index], context),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearHistory() {
    HapticUtil.heavy();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(I18n.of(context).clean_history),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              tagHistoryStore.deleteAll();
              Navigator.of(context).pop();
            },
            child: Text(I18n.of(context).ok),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(TrendTags tag) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => ResultPage(word: tag.tag)));
      },
      onLongPress: () {
        Navigator.of(context, rootNavigator: true).push(
          ArtworkPageRoute(
            builder: (_) => IllustLightingPage(id: tag.illust.id),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: PixivImage(
                tag.illust.imageUrls.squareMedium,
                fit: BoxFit.cover,
                fade: false,
                placeWidget: Center(
                  child: Text(I18n.of(context).footer_loading),
                ),
              ),
            ),
            Opacity(
              opacity: 0.4,
              child: Container(
                decoration: const BoxDecoration(color: Colors.black),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${tag.tag}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (tag.translatedName?.isNotEmpty == true)
                      Text(
                        tag.translatedName!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActionChip(TagsPersist f, BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticUtil.heavy();
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('${I18n.of(context).delete}?'),
              actions: [
                TextButton(
                  onPressed: () {
                    tagHistoryStore.delete(f.id!);
                    Navigator.of(context).pop();
                  },
                  child: Text(I18n.of(context).ok),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(I18n.of(context).cancel),
                ),
              ],
            );
          },
        );
      },
      child: ActionChip(
        padding: EdgeInsets.all(0.0),
        label: Text(
          f.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.0),
        ),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) =>
                  ResultPage(word: f.name, translatedName: f.translatedName),
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
