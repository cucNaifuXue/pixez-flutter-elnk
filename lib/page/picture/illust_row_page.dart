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

import 'package:bot_toast/bot_toast.dart';
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
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ban_illust_id.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/picture/illust_overview_page.dart';
import 'package:pixez/page/picture/illust_related_grid.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/picture/tag_for_illust_page.dart';
import 'package:pixez/page/user/user_store.dart';
import 'package:pixez/page/user/users_page.dart';
import 'package:pixez/page/zoom/photo_zoom_page.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:share_plus/share_plus.dart';

class IllustRowPage extends StatefulWidget {
  final int id;
  final String? heroString;
  final IllustStore? store;
  final GestureDragEndCallback? onHorizontalDragEnd;

  const IllustRowPage({
    Key? key,
    required this.id,
    this.heroString,
    this.store,
    this.onHorizontalDragEnd,
  }) : super(key: key);

  @override
  _IllustRowPageState createState() => _IllustRowPageState();
}

class _IllustRowPageState extends State<IllustRowPage>
    with AutomaticKeepAliveClientMixin {
  UserStore? userStore;
  late IllustStore _illustStore;
  late LightingStore _aboutStore;
  final _detailPager = SwipePagedGridController();
  final _imageController = ArtworkImageController();
  bool tempView = false;
  @override
  void initState() {
    _illustStore = widget.store ?? IllustStore(widget.id, null);
    _illustStore.fetch();
    _aboutStore = LightingStore(
      ApiSource(futureGet: () => apiClient.getIllustRelated(widget.id)),
    )..fetch();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant IllustRowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.store != widget.store) {
      userStore = null;
      _illustStore = widget.store ?? IllustStore(widget.id, null);
      _illustStore.fetch();
      _aboutStore = LightingStore(
        ApiSource(futureGet: () => apiClient.getIllustRelated(widget.id)),
      )..fetch();
      LPrinter.d("state change");
    }
  }

  void _loadAbout() {
    if (mounted && _aboutStore.iStores.isEmpty && !_aboutStore.refreshing)
      _aboutStore.fetch();
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
    _detailPager.dispose();
    _imageController.dispose();
    _illustStore.dispose();
    _aboutStore.dispose();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      extendBody: true,
      // appBar: AppBar(
      //   elevation: 0.0,
      //   // iconTheme: IconTheme.of(context).copyWith(color: Theme.of(context).textTheme!.bodyText1!.color),
      //   backgroundColor: Colors.transparent,
      //   actions: [
      //     IconButton(
      //         icon: Icon(Icons.more_vert),
      //         onPressed: () {
      //           buildShowModalBottomSheet(context, _illustStore.illusts!);
      //         })
      //   ],
      // ),
      extendBodyBehindAppBar: true,
      body: Observer(
        builder: (_) {
          if (!tempView)
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
          if (!tempView && _illustStore.illusts != null) {
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
              for (var t1 in _illustStore.illusts!.tags) {
                if (t.name == t1.name)
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
    );
  }

  Widget _buildBookmarkAction() => GestureDetector(
    onLongPress: _showBookMarkTag,
    onHorizontalDragEnd: (details) {
      widget.onHorizontalDragEnd?.call(details);
    },
    child: Observer(
      builder: (_) => IconButton(
        tooltip: I18n.of(context).bookmark,
        onPressed: () => _illustStore.star(),
        icon: StarIcon(state: _illustStore.state),
      ),
    ),
  );

  Widget colorText(String text, BuildContext context) => SelectionArea(
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
    ),
  );

  Widget _buildContent(BuildContext context, Illusts? data) {
    if (_illustStore.errorMessage != null) return _buildErrorContent(context);
    if (data == null) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    userStore ??= UserStore(data.user.id, null, data.user);
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
            sideBySide: true,
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

  Widget _buildNameAvatar(BuildContext context, Illusts illust) {
    if (userStore == null)
      userStore = UserStore(illust.user.id, null, illust.user);
    return Observer(
      builder: (_) {
        Future.delayed(Duration(seconds: 2), () {
          _loadAbout();
        });
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              child: GestureDetector(
                onLongPress: () {
                  userStore!.follow();
                },
                child: Container(
                  height: 70,
                  width: 70,
                  child: Stack(
                    children: <Widget>[
                      Center(
                        child: SizedBox(
                          height: 70,
                          width: 70,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: userStore!.isFollow
                                  ? Colors.yellow
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Hero(
                          tag:
                              illust.user.profileImageUrls.medium +
                              this.hashCode.toString(),
                          child: PainterAvatar(
                            url: illust.user.profileImageUrls.medium,
                            id: illust.user.id,
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
                      ),
                    ],
                  ),
                ),
              ),
              padding: EdgeInsets.all(8.0),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    SelectionArea(
                      child: Text(
                        illust.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    Container(height: 4.0),
                    Hero(
                      tag: illust.user.name + this.hashCode.toString(),
                      child: SelectionArea(
                        child: Text(
                          illust.user.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    Text(
                      illust.createDate.toShortTime(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
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
                  await _autoBookmarkAfterSave(illust);
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
                      onTap: () {
                        Navigator.of(context).pop("OK");
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
                            final link =
                                "https://www.pixiv.net/artworks/${widget.id}";
                            SharePlus.instance.share(
                              ShareParams(
                                text: link,
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
      _illustStore.star(restrict: restrict, tags: tags, force: true);
    }
  }

  @override
  bool get wantKeepAlive => false;
}
