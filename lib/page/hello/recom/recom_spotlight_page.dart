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
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/recom/recom_user_road.dart';
import 'package:pixez/page/hello/recom/spotlight_store.dart';
import 'package:pixez/page/soup/soup_page.dart';
import 'package:pixez/page/spotlight/spotlight_page.dart';

class RecomSpolightPage extends StatefulWidget {
  RecomSpolightPage({Key? key}) : super(key: key);

  @override
  _RecomSpolightPageState createState() => _RecomSpolightPageState();
}

class _RecomSpolightPageState extends State<RecomSpolightPage>
    with AutomaticKeepAliveClientMixin {
  late SpotlightStore spotlightStore;
  late LightingStore _lightingStore;
  late StreamSubscription<String> subscription;
  int _resetToken = 0;

  @override
  void dispose() {
    subscription.cancel();
    _lightingStore.dispose();
    super.dispose();
  }

  @override
  void initState() {
    spotlightStore = SpotlightStore(null);
    _lightingStore = LightingStore(
      ApiForceSource(
        futureGet: (e) => apiClient.getRecommend(),
        glanceKey: "recom",
      ),
    );
    super.initState();
    subscription = topStore.topStream.listen((event) {
      if (event == "100") {
        setState(() => _resetToken++);
      }
    });
    unawaited(spotlightStore.fetch());
    unawaited(_lightingStore.fetch());
  }

  Future<bool> _refresh() async {
    final results = await Future.wait([
      spotlightStore.fetch(),
      _lightingStore.fetch(force: true),
    ]);
    return results[1];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              _buildFirstRow(context),
              // Keep the spotlight entry available on smaller/landscape screens,
              // but reserve the banner strip for screens with enough grid space.
              if (constraints.maxHeight >= 600)
                Observer(builder: (_) => _buidTagSpotlightRow(context)),
              _buildSecondRow(context, I18n.of(context).recommend_for_you),
              Expanded(
                child: Observer(
                  builder: (_) {
                    _lightingStore.iStores.removeWhere(
                      (store) => store.illusts!.hateByUser(),
                    );
                    final stores = _lightingStore.iStores;
                    final orientation = MediaQuery.of(context).orientation;
                    final adaptive = orientation == Orientation.portrait
                        ? userSetting.crossAdapt
                        : userSetting.hCrossAdapt;
                    final columns = adaptive
                        ? _buildSliderValue(context, orientation)
                        : (orientation == Orientation.portrait
                              ? userSetting.crossCount
                              : userSetting.hCrossCount);
                    return SwipePagedGrid(
                      usePageLayout: true,
                      footerTrailingSpace: 72,
                      itemCount: stores.length,
                      crossAxisCount: columns,
                      resetToken: _resetToken,
                      isLoading: _lightingStore.refreshing,
                      hasMore: () => _lightingStore.nextUrl?.isNotEmpty == true,
                      onLoadMore: _loadMore,
                      onRefresh: _refresh,
                      loadingLabel: I18n.of(context).footer_loading,
                      emptyLabel: _lightingStore.errorMessage != null
                          ? I18n.of(context).loading_failed_retry_message
                          : I18n.of(context).no_more_data,
                      retryLabel: I18n.of(context).loading_failed_retry_message,
                      refreshLabel: I18n.of(context).refresh,
                      itemBuilder: (context, index) => IllustCard(
                        lightingStore: _lightingStore,
                        store: stores[index],
                        iStores: stores,
                        fitToCell: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _loadMore() async {
    final success = await _lightingStore.fetchNext();
    // nextUrl is not observable and can change even when all results are muted.
    if (mounted) setState(() {});
    return success;
  }

  int _buildSliderValue(BuildContext context, Orientation orientation) {
    final currentValue =
        (orientation == Orientation.portrait
                ? userSetting.crossAdapterWidth
                : userSetting.hCrossAdapterWidth)
            .toDouble();
    var nowAdaptWidth = max(currentValue, 50.0);
    nowAdaptWidth = min(nowAdaptWidth, 2160);
    return max(
      (MediaQuery.of(context).size.width / nowAdaptWidth),
      1.0,
    ).toInt();
  }

  Widget _buidTagSpotlightRow(BuildContext context) {
    var expectCardWidget = MediaQuery.of(context).size.width * 0.7;
    expectCardWidget = expectCardWidget > 244 ? 244 : expectCardWidget;
    final expectCardHeight = expectCardWidget * 0.525;
    return Container(
      height: expectCardHeight,
      padding: EdgeInsets.only(left: 0.0),
      child: spotlightStore.articles.isNotEmpty
          ? ListView.builder(
              itemBuilder: (context, index) {
                final spotlight = spotlightStore.articles[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.symmetric(horizontal: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  ),
                  child: Hero(
                    tag: "spotlight_image_${spotlight.hashCode}",
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (BuildContext context) {
                                return SoupPage(
                                  url: spotlight.articleUrl,
                                  spotlight: spotlight,
                                  heroTag:
                                      'spotlight_image_${spotlight.hashCode}',
                                );
                              },
                            ),
                          );
                        },
                        child: Container(
                          width: expectCardWidget,
                          height: expectCardHeight,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              image: PixivProvider.url(spotlight.thumbnail),
                            ),
                          ),
                          child: Container(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.0),
                                      Colors.black.withValues(alpha: 0.5),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${spotlight.title}",
                                          maxLines: 2,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            // shadows: [
                                            //   Shadow(
                                            //       color: Colors.black,
                                            //       offset: Offset(0.5, 0.5),
                                            //       blurRadius: 1.0)
                                            // ]
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              itemCount: spotlightStore.articles.length,
              scrollDirection: Axis.horizontal,
            )
          : Container(),
    );
  }

  Widget _buildFirstRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            child: Padding(
              child: Text(
                I18n.of(context).spotlight,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24.0,
                  color: Theme.of(context).textTheme.titleLarge!.color,
                ),
              ),
              padding: EdgeInsets.only(left: 20.0, bottom: 10.0),
            ),
          ),
          Padding(
            child: TextButton(
              child: Text(
                I18n.of(context).more,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return SpotLightPage();
                    },
                  ),
                );
              },
            ),
            padding: EdgeInsets.all(8.0),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondRow(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          child: Center(
            child: Text(
              title,
              overflow: TextOverflow.clip,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
            ),
          ),
          padding: EdgeInsets.only(left: 20.0),
        ),
        Expanded(child: RecomUserRoad()),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
