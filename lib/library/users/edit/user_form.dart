import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geo_monitor/library/data/country.dart';
import 'package:geo_monitor/library/users/edit/user_edit_mobile.dart';
import 'package:page_transition/page_transition.dart';
import 'package:uuid/uuid.dart';

import '../../api/data_api.dart';
import '../../api/prefs_og.dart';
import '../../bloc/admin_bloc.dart';
import '../../bloc/organization_bloc.dart';
import '../../cache_manager.dart';
import '../../data/user.dart' as ar;
import '../../data/user.dart';
import '../../functions.dart';
import '../../generic_functions.dart';
import '../avatar_editor.dart';
import '../full_user_photo.dart';
import 'country_chooser.dart';

class UserForm extends StatefulWidget {
  const UserForm({
    Key? key,
    this.user,
    required this.width,
    required this.internalPadding,
  }) : super(key: key);

  final ar.User? user;
  final double width, internalPadding;

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  var nameController = TextEditingController();
  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  var cellphoneController = TextEditingController();
  ar.User? admin;
  final _formKey = GlobalKey<FormState>();
  var isBusy = false;
  Country? country;
  int userType = -1;
  int genderType = -1;
  String? type;
  String? gender;

  UserFormStrings? userFormStrings;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _setup();
    _getAdministrator();
  }

  void _getAdministrator() async {
    admin = await prefsOGx.getUser();
    var sett = await prefsOGx.getSettings();
    if (sett != null) {
      userFormStrings = await UserFormStrings.getTranslated();
    }
    setState(() {});
  }

  Future<void> _setup() async {
    if (widget.user != null) {
      nameController.text = widget.user!.name!;
      emailController.text = widget.user!.email!;
      cellphoneController.text = widget.user!.cellphone!;
      _setTypeRadio();
      _setGenderRadio();
      await _setCountry();
    }
  }

  Future _setCountry() async {
    if (widget.user != null) {
      if (widget.user!.countryId != null) {
        var countries = await cacheManager.getCountries();
        for (var value in countries) {
          if (widget.user!.countryId == value.countryId) {
            country = value;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() async {
    if (country == null) {
      setState(() {
        busy = false;
      });
      showToast(
          context: context,
          message: 'Please select country',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.pink,
          textStyle: Styles.whiteSmall);

      return;
    }
    if (gender == null) {
      showToast(
          context: context,
          message: 'Please select user gender',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.pink,
          textStyle: Styles.whiteSmall);
      return;
    }
    if (type == null) {
      showToast(
          context: context,
          message: 'Please select user type',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.pink,
          textStyle: Styles.whiteSmall);
      return;
    }
    if (_formKey.currentState!.validate()) {
      //todo - validate
      pp('🔵🔵 ....... Submitting user data to create a new User!');

      setState(() {
        isBusy = true;
      });

      try {
        if (widget.user == null) {
          var user = ar.User(
              name: nameController.text,
              email: emailController.text,
              cellphone: cellphoneController.text,
              organizationId: admin!.organizationId!,
              organizationName: admin!.organizationName,
              countryId: country!.countryId,
              userType: type,
              gender: gender,
              active: 0,
              created: DateTime.now().toUtc().toIso8601String(),
              fcmRegistration: 'tbd',
              password: const Uuid().v4(),
              userId: 'tbd');
          pp('\n\n\n😡😡😡 _submit new user ......... ${user.toJson()}');
          try {
            var mUser = await DataAPI.createUser(user);
            pp('\n🍎🍎🍎🍎 UserEditTabletPortrait: 🍎 A user has been created:  🍎 '
                '${mUser.toJson()}\b');
            gender = null;
            type = null;
            if (mounted) {
              showToast(
                  message: 'User created: ${user.name}',
                  context: context,
                  backgroundColor: Colors.teal,
                  textStyle: Styles.whiteSmall,
                  toastGravity: ToastGravity.TOP,
                  duration: const Duration(seconds: 5));
            }

            await organizationBloc.getUsers(
                organizationId: user.organizationId!, forceRefresh: true);
            if (mounted) {
              Navigator.of(context).pop(mUser);
            }
          } catch (e) {
            pp(e);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('User Create failed: $e')));
          }
        } else {
          widget.user!.name = nameController.text;
          widget.user!.email = emailController.text;
          widget.user!.cellphone = cellphoneController.text;
          widget.user!.userType = type;
          widget.user!.countryId = country!.countryId!;
          widget.user!.gender = gender;

          pp('\n\n😡😡😡 _submit existing user for update, check countryId 🌸 ......... '
              '${widget.user!.toJson()} \n');

          try {
            await adminBloc.updateUser(widget.user!);
            var list = await organizationBloc.getUsers(
                organizationId: widget.user!.organizationId!,
                forceRefresh: true);
            if (mounted) {
              Navigator.pop(context, list);
            }
          } catch (e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Update failed: $e')));
          }
        }
      } catch (e) {
        pp(e);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      setState(() {
        isBusy = false;
      });
    }
  }

  void _handleGenderValueChange(Object? value) {
    pp('🌸 🌸 🌸 🌸 🌸 _handleGenderValueChange: 🌸 $value');
    setState(() {
      switch (value) {
        case 0:
          gender = 'Male';
          genderType = 0;
          break;
        case 1:
          gender = 'Female';
          genderType = 1;
          break;
        case 2:
          gender = 'Other';
          genderType = 2;
          break;
      }
    });
  }

  void _handleRadioValueChange(Object? value) {
    pp('🌸 🌸 🌸 🌸 🌸 _handleRadioValueChange: 🌸 $value');
    setState(() {
      switch (value) {
        case 0:
          type = UserType.fieldMonitor;
          userType = 0;
          break;
        case 1:
          type = UserType.orgAdministrator;
          userType = 1;
          break;
        case 2:
          type = UserType.orgExecutive;
          userType = 2;
          break;
      }
    });
  }

  void _setTypeRadio() {
    if (widget.user != null) {
      if (widget.user!.userType == UserType.fieldMonitor) {
        type = UserType.fieldMonitor;
        userType = 0;
      }
      if (widget.user!.userType == UserType.orgAdministrator) {
        type = UserType.orgAdministrator;
        userType = 1;
      }
      if (widget.user!.userType == UserType.orgExecutive) {
        type = UserType.orgExecutive;
        userType = 2;
      }
    }
  }

  void _setGenderRadio() {
    if (widget.user != null) {
      if (widget.user!.gender != null) {
        gender = widget.user!.gender!;
        switch (widget.user!.gender) {
          case 'Male':
            genderType = 0;
            break;
          case 'Female':
            genderType = 1;
            break;
        }
      }
    }
  }

  void _navigateToAvatarBuilder() async {
    //Navigator.of(context).pop();
    var user = await Navigator.push(
        context,
        PageTransition(
            type: PageTransitionType.scale,
            alignment: Alignment.topLeft,
            duration: const Duration(seconds: 2),
            child: AvatarEditor(
              user: widget.user!,
              goToDashboardWhenDone: false,
            )));
    if (user is User) {
      if (widget.user != null) {
        widget.user!.imageUrl = user.imageUrl;
        widget.user!.thumbnailUrl = user.thumbnailUrl;
        setState(() {});
      }
    }
  }

  void _navigateToFullPhoto() async {
    Navigator.of(context).pop();
    await Navigator.push(
        context,
        PageTransition(
            type: PageTransitionType.scale,
            alignment: Alignment.topLeft,
            duration: const Duration(seconds: 2),
            child: FullUserPhoto(
              user: widget.user!,
            )));
  }

  @override
  Widget build(BuildContext context) {
    var spaceToButtons = 0.0;
    var spaceToTop = 0.0;
    var ori = MediaQuery.of(context).orientation;
    if (ori.name == 'portrait') {
      spaceToButtons = 48;
      spaceToTop = 24;
    } else {
      spaceToButtons = 24;
      spaceToTop = 16;
    }
    return SizedBox(
      width: widget.width,
      child: Card(
        shape: getRoundedBorder(radius: 16),
        child: Padding(
          padding: EdgeInsets.all(widget.internalPadding),
          child: userFormStrings == null
              ? const SizedBox()
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 8,
                        ),
                        CountryChooser(
                          onSelected: (c) {
                            setState(() {
                              country = c;
                            });
                          },
                          hint: userFormStrings!.selectCountry,
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            const SizedBox(
                              width: 12,
                            ),
                            country == null
                                ? const SizedBox()
                                : Text(
                                    '${country!.name}',
                                    style: myTextStyleMedium(context),
                                  ),
                          ],
                        ),
                        SizedBox(
                          height: spaceToTop,
                        ),
                        TextFormField(
                          controller: nameController,
                          keyboardType: TextInputType.text,
                          style: myTextStyleSmall(context),
                          decoration: InputDecoration(
                              icon: Icon(
                                Icons.person,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              labelText: userFormStrings!.userName,
                              hintStyle: myTextStyleSmall(context),
                              hintText: userFormStrings!.enterFullName),
                          validator: (value) {
                            if (value!.isEmpty) {
                              return userFormStrings!.enterFullName;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: myTextStyleSmall(context),
                          decoration: InputDecoration(
                              icon: Icon(
                                Icons.email_outlined,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              labelText: userFormStrings!.emailAddress,
                              hintStyle: myTextStyleSmall(context),
                              hintText: userFormStrings!.enterEmail),
                          validator: (value) {
                            if (value!.isEmpty) {
                              return userFormStrings!.enterEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        TextFormField(
                          controller: cellphoneController,
                          keyboardType: TextInputType.phone,
                          style: myTextStyleSmall(context),
                          decoration: InputDecoration(
                              icon: Icon(
                                Icons.phone,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              labelText: userFormStrings!.cellphone,
                              hintStyle: myTextStyleSmall(context),
                              hintText: userFormStrings!.enterCell),
                          validator: (value) {
                            if (value!.isEmpty) {
                              return userFormStrings!.enterCell;
                            }
                            return null;
                          },
                        ),
                        SizedBox(
                          height: spaceToButtons,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Radio(
                              value: 0,
                              groupValue: genderType,
                              onChanged: _handleGenderValueChange,
                            ),
                            Text(
                              userFormStrings!.male,
                              style: myTextStyleSmall(context),
                            ),
                            Radio(
                              value: 1,
                              groupValue: genderType,
                              onChanged: _handleGenderValueChange,
                            ),
                            Text(userFormStrings!.female,
                                style: myTextStyleSmall(context)),
                          ],
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Column(
                          children: <Widget>[
                            Row(
                              children: [
                                Radio(
                                  value: 0,
                                  groupValue: userType,
                                  onChanged: _handleRadioValueChange,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  userFormStrings!.fieldMonitor,
                                  style: myTextStyleSmall(context),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Radio(
                                  value: 1,
                                  groupValue: userType,
                                  onChanged: _handleRadioValueChange,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Text(userFormStrings!.administrator,
                                    style: myTextStyleSmall(context)),
                              ],
                            ),
                            Row(
                              children: [
                                Radio(
                                  value: 2,
                                  groupValue: userType,
                                  onChanged: _handleRadioValueChange,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  userFormStrings!.executive,
                                  style: myTextStyleSmall(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(
                          height: spaceToButtons,
                        ),
                        isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 8,
                                  backgroundColor: Colors.black,
                                ),
                              )
                            : SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      userFormStrings!.submitMember,
                                      style: myTextStyleSmall(context),
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(
                          height: 16,
                        ),
                        SizedBox(
                          width: 200,
                          child: ElevatedButton(
                            onPressed: _navigateToAvatarBuilder,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                userFormStrings!.profilePhoto,
                                style: myTextStyleSmall(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
