import 'package:asyncstate/asyncstate.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

final class AppLoader extends AsyncOverlay {
  AppLoader()
      : super(
            id: 0,
            builder:
                (BuildContext context, AsyncValue<RouteSettings> settings) {
              return Center(
                  child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * .8,
                      child: LoadingAnimationWidget.staggeredDotsWave(
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      )));
            });
}
