import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/common/translation.dart';
import 'package:chitchat/const.dart';
import 'package:chitchat/overview/overview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
          'SETTINGS',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: new SettingsScreen(),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  State createState() => new SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  TextEditingController controllerNickname;

  SharedPreferences prefs;

  String id = '';
  String nickname = '';
  String photoUrl = '';
  String photosResolution = 'full';
  String theme = 'light';
  bool isLoading = false;
  TranslationLanguage _transationLanguage;
  TranslationMode _translationMode;
  File avatarImageFile;

  final FocusNode focusNodeNickname = new FocusNode();

  @override
  void initState() {
    super.initState();
    readLocal();
  }

  void readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
    nickname = prefs.getString('nickname') ?? '';
    photosResolution = (prefs.getString('photosResolution') == null ||
            prefs.getString('photosResolution') == '')
        ? 'full'
        : prefs.getString('photosResolution');

    theme = (prefs.getString('theme') == null ||
            prefs.getString('theme') == '')
        ? 'light'
        : prefs.getString('theme');

    photoUrl = prefs.getString('photoUrl') ?? '';
    this._transationLanguage = getTranslationLanguageFromString(
        prefs.getString("translation_language"));
    this._translationMode =
        getTranslationModeFromString(prefs.getString("translation_mode"));

    controllerNickname = new TextEditingController(text: nickname);

    // Force refresh input
    setState(() {});
  }

  Future getImage() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery, maxWidth: 640, maxHeight: 480);

    if (image != null) {
      setState(() {
        avatarImageFile = image;
        isLoading = true;
      });
    }
    uploadFile();
  }

  Future uploadFile() async {
    String fileName = id;
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(avatarImageFile);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    photoUrl = await storageTaskSnapshot.ref.getDownloadURL();
    Firestore.instance
        .collection('users')
        .document(id)
        .updateData({'photoUrl': photoUrl}).then((data) async {
      prefs.setString('photoUrl', photoUrl);
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "Upload success");
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  Future<void> handleUpdateData() async {
    focusNodeNickname.unfocus();

    setState(() {
      isLoading = true;
    });

    List<DocumentSnapshot> usersWithGivenNickname = (await Firestore.instance
            .collection("users")
            .where("nickname", isEqualTo: controllerNickname.text.trim())
            .getDocuments())
        .documents;

    usersWithGivenNickname.removeWhere((user) => user.documentID == id);
    if (usersWithGivenNickname.isNotEmpty) {
      Fluttertoast.showToast(msg: "The nickname provided already exists");
      setState(() {
        isLoading = false;
      });
      return;
    }

    changeTheme(theme);


    Firestore.instance.collection('users').document(id).updateData({
      'nickname': nickname,
      'photosResolution': photosResolution,
      'theme': theme,
      'translation_mode': this._translationMode.toString(),
      'translation_language': this._transationLanguage.toString()
    }).then((data) async {
      prefs.setString('nickname', nickname);
      prefs.setString('photosResolution', photosResolution);
      prefs.setString('theme', theme);
      prefs.setString('translation_mode', this._translationMode.toString());
      prefs.setString('translation_language', this._transationLanguage.toString());

      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "Update success");
      Navigator.push(
          context,
          new MaterialPageRoute(builder: (context) => MainScreen(currentUserId: this.prefs.get("id"), prefs: this.prefs,)));
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  void changeTheme(String theme){
    if(theme.compareTo('light') == 0) {
      DynamicTheme.of(context).setThemeData(new ThemeData(

      ));
      DynamicTheme.of(context).setBrightness(Brightness.light);
    }else{
      DynamicTheme.of(context).setThemeData(new ThemeData(

      ));
      DynamicTheme.of(context).setBrightness(Brightness.dark);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // Avatar
              Container(
                child: Center(
                  child: Stack(
                    children: <Widget>[
                      (avatarImageFile == null)
                          ? (photoUrl != ''
                              ? Material(
                                  child: CachedNetworkImage(
                                    placeholder: Container(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                themeColor),
                                      ),
                                      width: 90.0,
                                      height: 90.0,
                                      padding: EdgeInsets.all(20.0),
                                    ),
                                    imageUrl: photoUrl,
                                    width: 90.0,
                                    height: 90.0,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(45.0)),
                                  clipBehavior: Clip.hardEdge,
                                )
                              : Icon(
                                  Icons.account_circle,
                                  size: 90.0,
                                  color: greyColor,
                                ))
                          : Material(
                              child: Image.file(
                                avatarImageFile,
                                width: 90.0,
                                height: 90.0,
                                fit: BoxFit.cover,
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(45.0)),
                              clipBehavior: Clip.hardEdge,
                            ),
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          color: primaryColor.withOpacity(0.5),
                        ),
                        onPressed: getImage,
                        padding: EdgeInsets.all(30.0),
                        splashColor: Colors.transparent,
                        highlightColor: greyColor,
                        iconSize: 30.0,
                      ),
                    ],
                  ),
                ),
                width: double.infinity,
                margin: EdgeInsets.all(20.0),
              ),

              // Input
              Column(
                children: <Widget>[
                  // Username
                  Container(
                    child: Text(
                      'Nickname',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Sweetie',
                          contentPadding: new EdgeInsets.all(5.0),
                          hintStyle: TextStyle(color: greyColor),
                        ),
                        controller: controllerNickname,
                        onChanged: (value) {
                          nickname = value;
                        },
                        focusNode: focusNodeNickname,
                      ),
                    margin: EdgeInsets.only(left: 30.0, right: 30.0),
                  ),
                  Container(
                    child: Text(
                      'Photos resolution',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: photosResolution,
                      items:
                          <String>['full', 'high', 'low'].map((String value) {
                        return new DropdownMenuItem<String>(
                          value: value,
                          child: new Text(value),
                        );
                      }).toList(),
                      onChanged: (newResolution) {
                        setState(() {
                          photosResolution = newResolution;
                        });
                      },
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: Text(
                      'Message translation',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: DropdownButton<TranslationMode>(
                      isExpanded: true,
                      value: this._translationMode,
                      items: TranslationMode.values.map((translationMode) {
                        return DropdownMenuItem<TranslationMode>(
                          value: translationMode,
                          child: Text(getTranslationModeUsableString(translationMode)),
                        );
                      }).toList(),
                      onChanged: (newSetting) {
                        setState(() {
                          this._translationMode = newSetting;
                        });
                      },
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: Text(
                      'Translation language',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: DropdownButton<TranslationLanguage>(
                      isExpanded: true,
                      value: this._transationLanguage,
                      items: TranslationLanguage.values.map((translationLanguage) {
                        String languageUsableString = getTranslationLanguageUsableString(translationLanguage);
                        return DropdownMenuItem<TranslationLanguage>(
                          value: translationLanguage,
                          child: Text("${languageUsableString[0].toUpperCase()}${languageUsableString.substring(1)}"),    //Capitalize first letter
                        );
                      }).toList(),
                      onChanged: (newSetting) {
                        setState(() {
                          this._transationLanguage = newSetting;
                        });
                      },
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: Text(
                      'Theme',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: theme,
                      items:
                      <String>['Light', 'Dark'].map((String value) {
                        return new DropdownMenuItem<String>(
                          value: value.toLowerCase(),
                          child: new Text(value),
                        );
                      }).toList(),
                      onChanged: (newTheme) {
                        setState(() {
                          theme = newTheme;
                        });
                      },
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                ],
                crossAxisAlignment: CrossAxisAlignment.start,
              ),

              // Button
              Container(
                child: FlatButton(
                  onPressed: handleUpdateData,
                  child: Text(
                    'UPDATE',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  color: Theme.of(context).primaryColorDark,
                  highlightColor: Theme.of(context).highlightColor,
                  splashColor: Colors.transparent,
                  textColor: Theme.of(context).primaryColorLight,
                  padding: EdgeInsets.fromLTRB(30.0, 10.0, 30.0, 10.0),
                ),
                margin: EdgeInsets.only(top: 50.0, bottom: 50.0),
              ),
            ],
          ),
          padding: EdgeInsets.only(left: 15.0, right: 15.0),
        ),

        // Loading
        Positioned(
          child: isLoading
              ? Container(
                  child: Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor)),
                  ),
                  color: Colors.white.withOpacity(0.8),
                )
              : Container(),
        ),
      ],
    );
  }
}
