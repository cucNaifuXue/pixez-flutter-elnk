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

import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/ban_page.dart';
import 'package:pixez/component/common_back_area.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/star_icon.dart';
import 'package:pixez/component/artwork_image_controls.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ban_illust_id.dart';
import 'package:pixez/models/ban_tag.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/picture/illust_related_grid.dart';
import 'package:pixez/page/picture/illust_overview_page.dart';
import 'package:pixez/page/picture/illust_row_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/picture/tag_for_illust_page.dart';
import 'package:pixez/page/picture/user_follow_button.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:pixez/page/report/report_items_page.dart';
import 'package:pixez/page/search/result_page.dart';
import 'package:pixez/page/user/user_store.dart';
import 'package:pixez/page/user/users_page.dart';
import 'package:pixez/page/zoom/photo_zoom_page.dart';
import 'package:pixez/supportor_plugin.dart';
import 'package:share_plus/share_plus.dart';

class IllustLightingPage extends StatefulWidget {
  final int id;
  final String? heroString;
  final IllustStore? store;
  final GestureDragEndCallback? onHorizontalDragEnd;

  const IllustLightingPage({
    Key? key,
    required this.id,
    this.heroString,
    this.store,
    this.onHorizontalDragEnd,
  }) : super(key: key);

  @override
  State<IllustLightingPage> createState() => _IllustLightingPageState();
}

class _IllustLightingPageState extends State<IllustLightingPage> {
  @override
  Widget build(BuildContext context) {
    switch (userSetting.padMode) {
      case 0:
        MediaQueryData mediaQuery = MediaQuery.of(context);
        final ori = mediaQuery.size.width > mediaQuery.size.height;
        if (ori)
          return _buildRow();
        else
          return _buildVertical();
      case 1:
        return _buildVertical();
      case 2:
        return _buildRow();
      default:
        return Container();
    }
  }

  _buildVertical() {
    return IllustVerticalPage(
      id: widget.id,
      store: widget.store,
      heroString: widget.heroString,
      onHorizontalDragEnd: widget.onHorizontalDragEnd,
    );
  }

  _buildRow() {
    return IllustRowPage(
      id: widget.id,
      store: widget.store,
      heroString: widget.heroString,
      onHorizontalDragEnd: widget.onHorizontalDragEnd,
    );
  }
}

class IllustVerticalPage extends StatefulWidget {
  final int id;
  final String? heroString;
  final IllustStore? store;
  final GestureDragEndCallback? onHorizontalDragEnd;

  const IllustVerticalPage({
    Key? key,
    required this.id,
    this.heroString,
    this.store,
    this.onHorizontalDragEnd,
  }) : super(key: key);

  @override
  _IllustVerticalPageState createState() => _IllustVerticalPageState();
}

class _IllustVerticalPageState extends State<IllustVerticalPage>
    with AutomaticKeepAliveClientMixin {
  UserStore? userStore;
  late IllustStore _illustStore;
  late LightingStore _aboutStore;
  bool tempView = false;
  final _detailPager = SwipePagedGridController();
  final _imageController = ArtworkImageController();

  @override
  void initState() {
    _focusNode = FocusNode();
    _illustStore = widget.store ?? IllustStore(widget.id, null);
    _illustStore.fetch();
    _aboutStore = LightingStore(
      ApiSource(futureGet: () => apiClient.getIllustRelated(widget.id)),
    )..fetch();
    super.initState();
    supportTranslateCheck();
  }

  @override
  void didUpdateWidget(covariant IllustVerticalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.store != widget.store) {
      _illustStore = widget.store ?? IllustStore(widget.id, null);
      _illustStore.fetch();
      _aboutStore = LightingStore(
        ApiSource(futureGet: () => apiClient.getIllustRelated(widget.id)),
      )..fetch();
      userStore = null;
      LPrinter.d("state change");
    }
  }

  void _loadAbout() {
    if (mounted && _aboutStore.iStores.isEmpty && !_aboutStore.refreshing) {
      _aboutStore.fetch();
    }
  }

  Future<void> _autoBookmarkAfterSave(Illusts illust) async {
    if (!userSetting.starAfterSave) {
      return;
    }
    final targetStore = illust.id == _illustStore.id
        ? _illustStore
        : IllustStore(illust.id, illust);
    if (targetStore.state == 0) {
      await targetStore.star(
        restrict: userSetting.defaultPrivateLike ? "private" : "public",
      );
      try {
        final targetIllust = _aboutStore.iStores.firstWhere(
          (e) => e.id == illust.id,
        );
        targetIllust.illusts!.isBookmarked = true;
        if (mounted) {
          setState(() {});
        }
      } catch (e) {}
    }
  }

  @override
  void dispose() {
    _illustStore.dispose();
    _aboutStore.dispose();
    _detailPager.dispose();
    _imageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildAppbar() {
    return Column(
      children: [
        Container(height: MediaQuery.of(context).padding.top),
        Container(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CommonBackArea(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (buttonContext) {
                      return IconButton(
                        icon: Icon(Icons.more_vert),
                        onPressed: () {
                          HapticUtil.selectionClick();
                          buildShowModalBottomSheet(
                            buttonContext,
                            _illustStore.illusts!,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  late FocusNode _focusNode;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBody(context);
  }

  Widget _buildBookmarkAction() => GestureDetector(
    onLongPress: _showBookMarkTag,
    onHorizontalDragEnd: widget.onHorizontalDragEnd,
    child: Observer(
      builder: (context) => IconButton(
        tooltip: I18n.of(context).bookmark,
        onPressed: () async {
          if (userSetting.saveAfterStar && (_illustStore.state == 0)) {
            saveStore.saveImage(_illustStore.illusts!);
          }
          // TODO: 添加配置项 开关和过滤器
          final List<String>? tags;
          if (userSetting.autoTagWhenStar) {
            final filters = [RegExp(r"\d+users入り")];
            tags = _illustStore.illusts!.tags
                .map((tag) => tag.name)
                .where((tag) => !filters.any((regex) => regex.hasMatch(tag)))
                .toList();
          } else {
            tags = null;
          }
          bool success = await _illustStore.star(
            restrict: userSetting.defaultPrivateLike ? "private" : "public",
            tags: tags,
          );
          if (success && userSetting.followAfterStar) {
            bool followSuccess = await _illustStore.followAfterStar();
            if (followSuccess) {
              userStore?.isFollow = true;
              BotToast.showText(
                text:
                    "${_illustStore.illusts!.user.name} ${I18n.of(context).followed}",
              );
            }
          }
        },
        icon: StarIcon(state: _illustStore.state),
      ),
    ),
  );

  Widget _buildBody(BuildContext context) {
    return Container(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Observer(
            builder: (_) {
              final banWidget = banLogic(context);
              if (banWidget != null) {
                return banWidget;
              }
              return Container(
                child: Stack(
                  children: [
                    _buildContent(context, _illustStore.illusts),
                    _buildAppbar(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget? banLogic(BuildContext context) {
    if (tempView) return null;
    for (var i in muteStore.banillusts) {
      if (i.illustId == widget.id.toString()) {
        return BanPage(
          name: "${I18n.of(context).illust}\n${i.name}\n",
          onPressed: () {
            setState(() {
              tempView = true;
            });
          },
        );
      }
    }
    if (_illustStore.illusts != null) {
      for (var j in muteStore.banUserIds) {
        if (j.userId == _illustStore.illusts!.user.id.toString()) {
          return BanPage(
            name: "${I18n.of(context).painter}\n${j.name}\n",
            onPressed: () {
              setState(() {
                tempView = true;
              });
            },
          );
        }
      }
      for (var t in muteStore.banTags) {
        final tags = _illustStore.illusts!.tags;
        for (var t1 in tags) {
          if (t.isRegexMatch(t1.name)) {
            return BanPage(
              name: "${I18n.of(context).tag}\n${t.name}\n",
              onPressed: () {
                setState(() {
                  tempView = true;
                });
              },
            );
          }
        }
        final allText = tags.map((e) => '#${e.name}').join('');
        if (t.isRegexMatch(allText)) {
          return BanPage(
            name: "${I18n.of(context).tag}\n${t.name}\n",
            onPressed: () {
              setState(() {
                tempView = true;
              });
            },
          );
        }
      }
    }
    return null;
  }

  bool supportTranslate = false;

  Future<void> supportTranslateCheck() async {
    if (!Platform.isAndroid) return;
    bool results = await SupportorPlugin.processText();
    if (mounted) {
      setState(() {
        supportTranslate = results;
      });
    }
  }

  Widget colorText(String text, BuildContext context) {
    return SelectionArea(
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Illusts? data) {
    if (_illustStore.errorMessage != null) return _buildErrorContent(context);
    if (data == null)
      return Container(
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    if (userStore == null) userStore = UserStore(data.user.id, null, data.user);
    _imageController.configure(
      artworkId: data.id,
      imageCount: data.metaPages.length,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: IllustRelatedGrid(
          key: ValueKey(widget.id),
          store: _aboutStore,
          controller: _detailPager,
          footerAction: _buildBookmarkAction(),
          imageNavigation: ArtworkImageControls(controller: _imageController),
          firstPageBuilder: (context) => IllustOverviewPage(
            key: ValueKey(data.id),
            illusts: data,
            illustStore: _illustStore,
            userStore: userStore,
            heroString: widget.heroString,
            loadAbout: _loadAbout,
            onLongPressImage: (index) => _pressSave(data, index),
            onShowRelated: _detailPager.nextPage,
            embedded: true,
            imageController: _imageController,
          ),
        ),
      ),
    );
  }

  Center _buildErrorContent(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              ':(',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Text('${_illustStore.errorMessage}', maxLines: 5),
          ElevatedButton(
            onPressed: () {
              _illustStore.fetch();
            },
            child: Text(I18n.of(context).refresh),
          ),
        ],
      ),
    );
  }

  Future _longPressTag(BuildContext context, Tags f) async {
    switch (await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "${f.name}",
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (f.translatedName != null)
                  TextSpan(
                    text: "\n${"${f.translatedName}"}",
                    style: Theme.of(context).textTheme.bodyLarge!,
                  ),
              ],
            ),
          ),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 0);
              },
              child: Text(I18n.of(context).ban),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 1);
              },
              child: Text(I18n.of(context).bookmark),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 2);
              },
              child: Text(I18n.of(context).copy),
            ),
          ],
        );
      },
    )) {
      case 0:
        {
          muteStore.insertBanTag(
            BanTagPersist(name: f.name, translateName: f.translatedName ?? ""),
          );
        }
        break;
      case 1:
        {
          bookTagStore.bookTag(f.name);
        }
        break;
      case 2:
        {
          HapticUtil.light();
          await Clipboard.setData(ClipboardData(text: f.name));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text(I18n.of(context).copied_to_clipboard),
            ),
          );
        }
    }
  }

  Widget buildRow(BuildContext context, Tags f) {
    return GestureDetector(
      onLongPress: () async {
        HapticUtil.heavy();
        await _longPressTag(context, f);
      },
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return ResultPage(
                word: f.name,
                translatedName: f.translatedName ?? "",
              );
            },
          ),
        );
      },
      child: Container(
        height: 25,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.start,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              text: TextSpan(
                text: "#${f.name}",
                children: [
                  TextSpan(
                    text: " ",
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall!.copyWith(fontSize: 12),
                  ),
                  if (f.translatedName != null)
                    TextSpan(
                      text: "${f.translatedName}",
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall!.copyWith(fontSize: 12),
                    ),
                ],
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameAvatar(BuildContext context, Illusts illust) {
    if (userStore == null)
      userStore = UserStore(illust.user.id, null, illust.user);
    return Observer(
      builder: (_) {
        Future.delayed(Duration(seconds: 2), () {
          _loadAbout();
        });
        return InkWell(
          onTap: () async {
            await _push2UserPage(context, illust);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                child: Hero(
                  tag:
                      illust.user.profileImageUrls.medium +
                      this.hashCode.toString(),
                  child: PainterAvatar(
                    url: illust.user.profileImageUrls.medium,
                    id: illust.user.id,
                    size: Size(32, 32),
                    onTap: () async {
                      await Leader.push(
                        context,
                        UsersPage(
                          id: illust.user.id,
                          userStore: userStore,
                          heroTag: this.hashCode.toString(),
                        ),
                      );
                      _illustStore.illusts!.user.isFollowed =
                          userStore!.isFollow;
                    },
                  ),
                ),
                padding: EdgeInsets.only(left: 16.0),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Hero(
                        tag: illust.user.name + this.hashCode.toString(),
                        child: SelectionArea(
                          child: Text(
                            illust.user.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall!.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              UserFollowButton(
                id: illust.user.id,
                followed:
                    userStore?.isFollow ?? illust.user.isFollowed ?? false,
                onPressed: () async {
                  await userStore?.follow();
                  if (userStore?.isFollow != null) {
                    _illustStore.illusts?.user.isFollowed = userStore?.isFollow;
                  }
                },
                onConfirm: (follow, restrict) {
                  userStore?.followWithRestrict(follow, restrict);
                  if (userStore?.isFollow != null) {
                    _illustStore.illusts?.user.isFollowed = userStore?.isFollow;
                  }
                },
              ),
              SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _push2UserPage(BuildContext context, Illusts illust) async {
    await Leader.push(
      context,
      UsersPage(
        id: illust.user.id,
        userStore: userStore,
        heroTag: this.hashCode.toString(),
      ),
    );
    _illustStore.illusts!.user.isFollowed = userStore!.isFollow;
  }

  Future<void> _pressSave(Illusts illust, int index) async {
    HapticUtil.heavy();
    if (userSetting.illustDetailSaveSkipLongPress) {
      saveStore.saveImage(illust, index: index);
      await _autoBookmarkAfterSave(illust);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c1) {
        return Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              illust.metaPages.isNotEmpty
                  ? ListTile(
                      title: Text(I18n.of(context).muti_choice_save),
                      leading: Icon(Icons.save),
                      onTap: () async {
                        Navigator.of(context).pop();
                        _showMutiChoiceDialog(illust, context);
                      },
                    )
                  : Container(),
              ListTile(
                leading: Icon(Icons.save_alt),
                onTap: () async {
                  Navigator.of(context).pop();
                  saveStore.saveImage(illust, index: index);
                  await _autoBookmarkAfterSave(illust);
                },
                onLongPress: () async {
                  Navigator.of(context).pop();
                  saveStore.saveImage(illust, index: index);
                },
                title: Text(I18n.of(context).save),
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                onTap: () => Navigator.of(context).pop(),
                title: Text(I18n.of(context).cancel),
              ),
              Container(height: MediaQuery.of(c1).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Future _showMutiChoiceDialog(Illusts illust, BuildContext context) async {
    List<bool> indexs = [];
    bool allOn = false;
    for (int i = 0; i < illust.metaPages.length; i++) {
      indexs.add(false);
    }
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    Container(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(illust.title),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        itemBuilder: (context, index) {
                          final data = illust.metaPages[index];
                          return Container(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    indexs[index] = !indexs[index];
                                  });
                                },
                                onLongPress: () {
                                  Leader.push(
                                    context,
                                    PhotoZoomPage(
                                      index: index,
                                      illusts: illust,
                                      illustStore: _illustStore,
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    PixivImage(
                                      data.imageUrls!.squareMedium,
                                      placeWidget: Container(
                                        child: Center(
                                          child: Text(index.toString()),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Visibility(
                                        visible: indexs[index],
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        itemCount: illust.metaPages.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        !allOn
                            ? Icons.check_circle_outline
                            : Icons.check_circle,
                      ),
                      title: Text(I18n.of(context).all),
                      onTap: () {
                        allOn = !allOn;
                        for (var i = 0; i < indexs.length; i++) {
                          indexs[i] = allOn;
                        }
                        setDialogState(() {});
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.save),
                      title: Text(I18n.of(context).save),
                      onTap: () async {
                        Navigator.of(context).pop("OK");
                        if (userSetting.starAfterSave &&
                            (_illustStore.state == 0)) {
                          bool success = await _illustStore.star(
                            restrict: userSetting.defaultPrivateLike
                                ? "private"
                                : "public",
                          );
                          if (success && userSetting.followAfterStar) {
                            await _illustStore.followAfterStar();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    switch (result) {
      case "OK":
        {
          saveStore.saveChoiceImage(illust, indexs);
        }
    }
  }

  Future buildShowModalBottomSheet(BuildContext context, Illusts illusts) {
    final buttonBox = context.findRenderObject() as RenderBox?;
    final shareOrigin = buttonBox != null
        ? buttonBox.localToGlobal(Offset.zero) & buttonBox.size
        : null;
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final width = (MediaQuery.sizeOf(dialogContext).width - 24).clamp(
          0.0,
          320.0,
        );
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 12, left: 12),
              child: Material(
                color: Theme.of(dialogContext).colorScheme.surface,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.75,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(height: 8),
                        _buildNameAvatar(dialogContext, illusts),
                        if (illusts.metaPages.isNotEmpty)
                          ListTile(
                            title: Text(
                              I18n.of(dialogContext).muti_choice_save,
                            ),
                            leading: Icon(Icons.save),
                            onTap: () async {
                              Navigator.of(dialogContext).pop();
                              _showMutiChoiceDialog(illusts, context);
                            },
                          ),
                        ListTile(
                          title: Text(I18n.of(dialogContext).copymessage),
                          leading: Icon(Icons.local_library),
                          onTap: () async {
                            final str = userSetting.illustToShareInfoText(
                              illusts,
                            );
                            await Clipboard.setData(ClipboardData(text: str));
                            BotToast.showText(
                              text: I18n.of(dialogContext).copied_to_clipboard,
                            );
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        ListTile(
                          title: Text(I18n.of(dialogContext).share),
                          leading: Icon(Icons.share),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            SharePlus.instance.share(
                              ShareParams(
                                text:
                                    "https://www.pixiv.net/artworks/${widget.id}",
                                sharePositionOrigin: shareOrigin,
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.link),
                          title: Text(I18n.of(dialogContext).link),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    "https://www.pixiv.net/artworks/${widget.id}",
                              ),
                            );
                            BotToast.showText(
                              text: I18n.of(dialogContext).copied_to_clipboard,
                            );
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        ListTile(
                          title: Text(I18n.of(dialogContext).ban),
                          leading: Icon(Icons.brightness_auto),
                          onTap: () {
                            muteStore.insertBanIllusts(
                              BanIllustIdPersist(
                                illustId: widget.id.toString(),
                                name: illusts.title,
                              ),
                            );
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        ListTile(
                          title: Text(I18n.of(dialogContext).report),
                          leading: Icon(Icons.report),
                          onTap: () async {
                            if (Platform.isAndroid) {
                              Navigator.of(dialogContext).pop();
                              await Reporter.show(
                                context,
                                () async => await muteStore.insertBanIllusts(
                                  BanIllustIdPersist(
                                    illustId: widget.id.toString(),
                                    name: illusts.title,
                                  ),
                                ),
                              );
                            } else {
                              await showDialog(
                                context: dialogContext,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text(I18n.of(context).report),
                                    content: Text(
                                      I18n.of(context).report_message,
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text(I18n.of(context).cancel),
                                        onPressed: () {
                                          Navigator.of(context).pop("CANCEL");
                                        },
                                      ),
                                      TextButton(
                                        child: Text(I18n.of(context).ok),
                                        onPressed: () {
                                          Navigator.of(context).pop("OK");
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          },
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showBookMarkTag() async {
    HapticUtil.heavy();
    final result = await Leader.pushWithScaffold(
      context,
      TagForIllustPage(id: widget.id),
    );
    if (result is Map) {
      LPrinter.d(result);
      String restrict = result['restrict'];
      List<String>? tags = result['tags'];
      if (userSetting.saveAfterStar && (_illustStore.state == 0)) {
        saveStore.saveImage(_illustStore.illusts!);
      }
      bool success = await _illustStore.star(
        restrict: restrict,
        tags: tags,
        force: true,
      );
      if (success && userSetting.followAfterStar) {
        await _illustStore.followAfterStar();
      }
    }
  }

  @override
  bool get wantKeepAlive => false;
}

class TextSelectionFix {
  static TextSelectionControls? buildControls(BuildContext context) {
    TextSelectionControls? controls = null;
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        controls ??= materialTextSelectionControls;
        break;
      case TargetPlatform.iOS:
        controls ??= cupertinoTextSelectionControls;
        break;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        controls ??= desktopTextSelectionControls;
        break;
      case TargetPlatform.macOS:
        controls ??= cupertinoDesktopTextSelectionControls;
        break;
    }
    return controls;
  }
}
