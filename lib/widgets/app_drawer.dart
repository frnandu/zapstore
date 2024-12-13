import 'dart:io';

import 'package:amberflutter/amberflutter.dart';
import 'package:async_button_builder/async_button_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zapstore/main.data.dart';
import 'package:zapstore/models/settings.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/widgets/rounded_image.dart';

class LoginContainer extends HookConsumerWidget {
  final String labelText;
  final bool minimal;
  final amber = Amberflutter();

  LoginContainer(
      {super.key,
      this.minimal = false,
      this.labelText = 'Input your NIP-05 or npub (no nsec!)'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.settings
        .watchOne('_', alsoWatch: (_) => {_.user})
        .model
        ?.user
        .value;
    final controller = useTextEditingController();
    final isTextFieldEmpty = useState(true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (!minimal) RoundedImage(url: user?.avatarUrl, size: 46),
            if (!minimal) Gap(10),
            if (user != null && !minimal)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.nameOrNpub,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Gap(4),
                      Icon(Icons.verified, color: Colors.lightBlue, size: 18),
                    ],
                  ),
                  // if (user.following.isNotEmpty)
                  //   Text('${user.following.length} contacts'),
                ],
              ),
          ],
        ),
        if (user == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(20),
              Text(labelText),
              TextField(
                autocorrect: false,
                controller: controller,
                onChanged: (value) {
                  isTextFieldEmpty.value = value.isEmpty;
                },
                decoration: InputDecoration(
                  hintText: 'your@nip05 or npub',
                  suffixIcon: AsyncButtonBuilder(
                    disabled: isTextFieldEmpty.value,
                    loadingWidget: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(),
                    ),
                    onPressed: () async {
                      return doLogin(ref, controller.text.trim(), context);
                    },
                    builder: (context, child, callback, buttonState) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SizedBox(
                          child: ElevatedButton(
                            onPressed: callback,
                            style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: Colors.transparent,
                                backgroundColor: Colors.transparent),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Text('Log in'),
                  ),
                ),
              ),
              Gap(10),
              isAndroid()
                  ? AsyncButtonBuilder(
                      loadingWidget: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(),
                      ),
                      onPressed: () async {
                        if (await amber.isAppInstalled()) {
                          final npub = await getExternalSignerPublicKey().catchError((e, stack) {
                            print("error");
                          });
                          return doLogin(ref, npub, context);
                        } else {
                          var url =
                              Uri.parse("https://github.com/greenart7c3/Amber");
                          launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      builder: (context, child, callback, buttonState) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: SizedBox(
                            child: ElevatedButton(
                              onPressed: callback,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Text('Login with external signer'),
                    )
                  : Container()
            ],
          ),
        Gap(5),
        if (user != null && !minimal)
          ElevatedButton(
            onPressed: () async {
              ref.settings.findOneLocalById('_')!.user.value = null;
              controller.clear();
            },
            child: Text('Log out'),
          ),
      ],
    );
  }

  Future<void> doLogin(WidgetRef ref, String pubKey, BuildContext context) {
    return ref.users.findOne(pubKey).then((user) {
      ref.settings.findOneLocalById('_')!.user.value =
          user;
    }).catchError((e, stack) {
      if (context.mounted) {
        context.showError(
            title: e.message ?? e.toString(),
            description:
                stack?.toString().substringMax(200));
      }
    });
  }

  static bool isAndroid() {
    try {
      return Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  Future<String> getExternalSignerPublicKey() async {
    final key = await amber.getPublicKey();
    return key['signature'];
  }
}
