import 'package:PiliPlus/common/motion/cover_hero.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_status.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// The cover in the player until the video's first frame is on screen.
///
/// It sits between the black background and a transparent video, so the
/// player's controls stay on top. It is also where the card's cover lands
/// when it flies in, instead of a black box while the video loads.
class FirstFrameCover extends StatefulWidget {
  const FirstFrameCover({
    super.key,
    required this.controller,
    required this.cover,
    required this.heroTag,
    required this.width,
    required this.height,
  });

  final PlPlayerController controller;
  final RxString cover;
  final Object? heroTag;
  final double width;
  final double height;

  @override
  State<FirstFrameCover> createState() => _FirstFrameCoverState();
}

class _FirstFrameCoverState extends State<FirstFrameCover> {
  bool _frameShown = false;
  VideoController? _watching;

  void _watch(VideoController? controller) {
    if (controller == null || identical(controller, _watching)) return;
    _watching = controller;
    controller.waitUntilFirstFrameRendered.then((_) {
      if (mounted && identical(_watching, controller)) {
        setState(() => _frameShown = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // dataStatus changes when the video controller is created
      final failed = widget.controller.dataStatus.value == DataStatus.error;
      _watch(widget.controller.videoController);
      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: _frameShown || failed ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: CoverHero(
            tag: widget.heroTag,
            borderRadius: BorderRadius.zero,
            child: NetworkImgLayer(
              src: widget.cover.value,
              width: widget.width,
              height: widget.height,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      );
    });
  }
}
