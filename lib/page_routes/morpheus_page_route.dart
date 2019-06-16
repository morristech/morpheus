import 'package:flutter/material.dart';
import '../tweens/vertical_transition_child_tween.dart';
import '../tweens/vertical_transition_opacity_tween.dart';

/// PageRoute that implements a parent-child transition as defined in the
/// Material Design guidelines.
///
/// The type `T` specifies the return type of the route which can be supplied
/// as the route is popped from the stack via [Navigator.pop] by providing the
/// optional `result` argument.
///
/// Thanks to Github user flschweiger for inspiring refactorings :)
class MorpheusPageRoute<T> extends PageRoute<T> {
  /// Construct a MorpheusPageRoute whose contents are defined by [builder].
  ///
  /// The values of [builder], [parentKey], [transitionDuration], [elevation],
  /// and [scrimColor] must not be null.
  MorpheusPageRoute({
    @required this.builder,
    @required this.parentKey,
    this.transitionDuration = const Duration(milliseconds: 500),
    this.scrimColor = Colors.black45,
    this.borderRadius,
    this.transitionColor,
    this.transitionToChild = true,
    RouteSettings settings,
  })  : assert(builder != null),
        assert(parentKey != null),
        assert(transitionDuration != null),
        assert(scrimColor != null),
        _renderBoxOffset = _getOffset(parentKey),
        _renderBoxSize = _getSize(parentKey),
        _verticalTransitionWidget = _getVerticalTransitionWidget(
          parentKey,
          transitionColor,
        ),
        super(settings: settings);

  /// Builds the contents of the route.
  final WidgetBuilder builder;

  /// A [GlobalKey] that is used to calculate the transition so that it looks
  /// like the element that [parentKey] is attached to turns into a new page
  /// with the contents of [builder].
  final GlobalKey parentKey;

  /// Creates an overlay that covers the content outside of the
  /// MorpheusPageRoute.
  final Color scrimColor;

  /// Defines the initial border-radius of the transition.
  final BorderRadiusGeometry borderRadius;

  /// The color that is used when transitioning from the parent element to the
  /// contents of [builder].
  final Color transitionColor;

  /// Defines whether the animation should transition from a temporary widget
  /// into the contents of [builder] or not.
  final bool transitionToChild;

  /// Used to calculate the transition's [Offset]
  Offset _renderBoxOffset;

  /// Used to calculate the transition's [Size]
  Size _renderBoxSize;

  Widget _verticalTransitionWidget;

  static RenderBox _findRenderBox(GlobalKey parentKey) =>
      parentKey.currentContext.findRenderObject();

  static Offset _getOffset(GlobalKey parentKey) {
    return _findRenderBox(parentKey).localToGlobal(Offset.zero);
  }

  static Size _getSize(GlobalKey parentKey) {
    return _findRenderBox(parentKey).size;
  }

  @override
  final Duration transitionDuration;

  @override
  final bool opaque = true;

  @override
  final bool barrierDismissible = false;

  @override
  final Color barrierColor = null;

  @override
  final String barrierLabel = null;

  @override
  final bool maintainState = true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Builder(builder: builder);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final Animation<Color> scrimAnimation = ColorTween(
      begin: scrimColor.withOpacity(0.0),
      end: scrimColor,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    ));

    return Container(
      color: scrimAnimation.value,
      child: _transitionsBuilder(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    );
  }

  Widget _transitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Interval(
        0.0,
        _renderBoxOffset.dx > 0.0 ? 0.2 : 0.1,
        curve: Curves.fastOutSlowIn,
      ),
      reverseCurve: Interval(
        0.0,
        _renderBoxOffset.dx > 0.0 ? 0.2 : 0.1,
        curve: Curves.fastOutSlowIn.flipped,
      ),
    ));

    return LayoutBuilder(
      builder: (context, constraints) {
        final source = _renderBoxOffset & _renderBoxSize;

        final Animation<double> positionAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(
            _renderBoxOffset.dx > 0.0 ? 0.2 : 0.0,
            1.0,
            curve: Curves.fastOutSlowIn,
          ),
          reverseCurve: Interval(
            _renderBoxOffset.dx > 0.0 ? 0.2 : 0.0,
            1.0,
            curve: Curves.fastOutSlowIn.flipped,
          ),
        );

        /// Animates the child screen position.
        final Animation<RelativeRect> itemPosition = RelativeRectTween(
          begin: RelativeRect.fromLTRB(
              source.left,
              source.top,
              constraints.biggest.width - source.right,
              constraints.biggest.height - source.bottom),
          end: RelativeRect.fill,
        ).animate(positionAnimation);

        final BorderRadiusTween borderTween = BorderRadiusTween(
          begin: borderRadius ?? BorderRadius.circular(0.0),
          end: BorderRadius.circular(0.0),
        );

        /// Fades in the child screen from a color.
        final Animation<double> fadeInChild = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.2, 1, curve: Curves.ease),
        );

        /// Scales the child screen.
        final Animation<double> scaleAnimation = Tween<double>(
          begin: _renderBoxSize.width / MediaQuery.of(context).size.width,
          end: 1.0,
        ).animate(positionAnimation);

        return FadeTransition(
          opacity: fadeIn,
          child: Stack(
            children: <Widget>[
              PositionedTransition(
                rect: itemPosition,
                child: AnimatedBuilder(
                  animation: positionAnimation,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                    maxHeight: constraints.maxHeight,
                    child: child,
                  ),
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: borderTween.evaluate(positionAnimation),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            color:
                                transitionColor ?? Theme.of(context).cardColor,
                          ),
                          transitionToChild
                              ? _renderBoxOffset.dx > 0.0
                                  ? FadeTransition(
                                      opacity: fadeInChild,
                                      child: ScaleTransition(
                                        alignment: Alignment.topCenter,
                                        scale: scaleAnimation,
                                        child: child,
                                      ),
                                    )
                                  : FadeTransition(
                                      opacity: VerticalTransitionOpacityTween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.fastOutSlowIn,
                                      )),
                                      child: VerticalTransitionChildTween(
                                        begin: _verticalTransitionWidget,
                                        end: child,
                                      )
                                          .animate(CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.fastOutSlowIn,
                                          ))
                                          .value,
                                    )
                              : child,
                        ],
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

  static Widget _getVerticalTransitionWidget(
    GlobalKey parentKey,
    Color transitionColor,
  ) {
    final Widget parentWidget = parentKey.currentWidget;
    if (parentWidget is ListTile) {
      return Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: () => null,
          trailing: parentWidget.trailing,
          title: parentWidget.title,
          contentPadding: parentWidget.contentPadding,
          isThreeLine: parentWidget.isThreeLine,
          subtitle: parentWidget.subtitle,
          leading: parentWidget.leading,
          dense: parentWidget.dense,
          enabled: parentWidget.enabled,
          onLongPress: () => null,
          selected: parentWidget.selected,
        ),
      );
    } else {
      return Container(
        color: transitionColor,
      );
    }
  }
}
