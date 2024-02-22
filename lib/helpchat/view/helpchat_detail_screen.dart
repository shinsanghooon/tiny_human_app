import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tiny_human_app/common/constant/colors.dart';
import 'package:tiny_human_app/helpchat/provider/chat_provider.dart';

import '../../common/constant/firestore_constants.dart';
import '../component/full_photo_page.dart';
import '../enum/type_messages.dart';
import '../model/chat_page_info.dart';
import '../model/message_chat.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int id;
  final ChatPageInfo chatData;

  const ChatScreen({
    required this.id,
    required this.chatData,
    super.key,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final String _currentUserId = '12123';

  List<QueryDocumentSnapshot> _listMessage = [];
  int _limit = 20;
  final _limitIncrement = 20;
  String _groupChatId = "";

  File? _imageFile;
  bool _isLoading = false;
  bool _isShowSticker = false;
  String _imageUrl = "";

  final _chatInputController = TextEditingController();
  final _listScrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _listScrollController.addListener(_scrollListener);
    _readLocal();
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _listScrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_listScrollController.hasClients) return;
    if (_listScrollController.offset >= _listScrollController.position.maxScrollExtent &&
        !_listScrollController.position.outOfRange &&
        _limit <= _listMessage.length) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Hide sticker when keyboard appear
      setState(() {
        _isShowSticker = false;
      });
    }
  }

  void _readLocal() {
    // if (_authProvider.userFirebaseId?.isNotEmpty == true) {
    //   _currentUserId = _authProvider.userFirebaseId!;
    // } else {
    //   Navigator.of(context).pushAndRemoveUntil(
    //     MaterialPageRoute(builder: (_) => LoginScreen()),
    //     (_) => false,
    //   );
    // }

    // String peerId = widget.chatData.peerId;
    // if (_currentUserId.compareTo(peerId) > 0) {
    //   _groupChatId = '$_currentUserId-$peerId';
    // } else {
    //   _groupChatId = '$peerId-$_currentUserId';
    // }

    // _chatProvider.updateDataFirestore(
    //   FirestoreConstants.pathUserCollection,
    //   _currentUserId,
    //   {FirestoreConstants.chattingWith: peerId},
    // );
  }

  Future<bool> _pickImage() async {
    final imagePicker = ImagePicker();
    final pickedXFile = await imagePicker.pickImage(source: ImageSource.gallery).catchError((err) {
      Fluttertoast.showToast(msg: err.toString());
      return null;
    });
    if (pickedXFile != null) {
      final imageFile = File(pickedXFile.path);
      setState(() {
        _imageFile = imageFile;
        _isLoading = true;
      });
      return true;
    } else {
      return false;
    }
  }

  Future<void> _uploadFile(_chatProvider) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final uploadTask = _chatProvider.uploadFile(_imageFile!, fileName);
    try {
      final snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        _isLoading = false;
        _onSendMessage(_chatProvider, _imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  void _onSendMessage(_chatProvider, String content, int type) {
    if (content.trim().isNotEmpty) {
      _chatInputController.clear();
      _chatProvider.sendMessage(content, type, _groupChatId, _currentUserId, widget.chatData.peerId);
      if (_listScrollController.hasClients) {
        _listScrollController.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else {
      Fluttertoast.showToast(msg: 'Nothing to send', backgroundColor: Colors.grey);
    }
  }

  Widget _buildItemMessage(int index, DocumentSnapshot? document) {
    final _chatProvider = ref.watch(chatProvider);

    if (document == null) return SizedBox.shrink();
    final messageChat = MessageChat.fromDocument(document);
    if (messageChat.idFrom == _currentUserId) {
      // Right (my message)
      return Row(
        children: [
          messageChat.type == TypeMessage.text
              // Text
              ? Container(
                  child: Text(
                    messageChat.content,
                    style: TextStyle(color: PRIMARY_COLOR),
                  ),
                  padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                  width: 200,
                  decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(8)),
                  margin: EdgeInsets.only(bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                )
              : messageChat.type == TypeMessage.image
                  // Image
                  ? Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      child: GestureDetector(
                        child: Image.network(
                          messageChat.content,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              width: 200,
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: PRIMARY_COLOR,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return Image.asset(
                              'images/img_not_available.jpeg',
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            );
                          },
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullPhotoPage(
                                url: messageChat.content,
                              ),
                            ),
                          );
                        },
                      ),
                      margin: EdgeInsets.only(bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                    )
                  // Sticker
                  : Container(
                      child: Image.asset(
                        'images/${messageChat.content}.gif',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      margin: EdgeInsets.only(bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                    ),
        ],
        mainAxisAlignment: MainAxisAlignment.end,
      );
    } else {
      // Left (peer message)
      return Container(
        child: Column(
          children: [
            Row(
              children: [
                messageChat.type == TypeMessage.text
                    ? Container(
                        child: Text(
                          messageChat.content,
                          style: TextStyle(color: Colors.white),
                        ),
                        padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                        width: 200,
                        decoration: BoxDecoration(color: PRIMARY_COLOR, borderRadius: BorderRadius.circular(8)),
                        margin: EdgeInsets.only(left: 10),
                      )
                    : messageChat.type == TypeMessage.image
                        ? Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                            child: GestureDetector(
                              child: Image.network(
                                messageChat.content,
                                loadingBuilder: (_, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    width: 200,
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: PRIMARY_COLOR,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'images/img_not_available.jpeg',
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullPhotoPage(url: messageChat.content),
                                  ),
                                );
                              },
                            ),
                            margin: EdgeInsets.only(left: 10),
                          )
                        : Container(
                            child: Image.asset(
                              'images/${messageChat.content}.gif',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                            margin: EdgeInsets.only(bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                          ),
              ],
            ),

            // Time
            _isLastMessageLeft(index)
                ? Container(
                    child: Text(
                      DateFormat('dd MMM kk:mm')
                          .format(DateTime.fromMillisecondsSinceEpoch(int.parse(messageChat.timestamp))),
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    margin: EdgeInsets.only(left: 50, top: 5, bottom: 5),
                  )
                : SizedBox.shrink()
          ],
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        margin: EdgeInsets.only(bottom: 10),
      );
    }
  }

  bool _isLastMessageLeft(int index) {
    if ((index > 0 && _listMessage[index - 1].get(FirestoreConstants.idFrom) == _currentUserId) || index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool _isLastMessageRight(int index) {
    if ((index > 0 && _listMessage[index - 1].get(FirestoreConstants.idFrom) != _currentUserId) || index == 0) {
      return true;
    } else {
      return false;
    }
  }

  void _onBackPress(_chatProvider) {
    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: null},
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final _chatProvider = ref.watch(chatProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          this.widget.chatData.peerNickname,
          style: TextStyle(color: PRIMARY_COLOR),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: PopScope(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildListMessage(chatProvider),
                  _isShowSticker ? _buildStickers(_chatProvider) : SizedBox.shrink(),
                  _buildInput(_chatProvider),
                ],
              ),
              Positioned(
                child: _isLoading ? CircularProgressIndicator() : SizedBox.shrink(),
              ),
            ],
          ),
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            _onBackPress(chatProvider);
          },
        ),
      ),
    );
  }

  Widget _buildStickers(chatProvider) {
    return Container(
      child: Column(
        children: [
          Row(
            children: [
              _buildItemSticker("mimi1", chatProvider),
              _buildItemSticker("mimi2", chatProvider),
              _buildItemSticker("mimi3", chatProvider),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: [
              _buildItemSticker("mimi4", chatProvider),
              _buildItemSticker("mimi5", chatProvider),
              _buildItemSticker("mimi6", chatProvider),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: [
              _buildItemSticker("mimi7", chatProvider),
              _buildItemSticker("mimi8", chatProvider),
              _buildItemSticker("mimi9", chatProvider),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          )
        ],
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        color: Colors.white,
      ),
      padding: EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildItemSticker(String stickerName, chatProvider) {
    return TextButton(
      onPressed: () => _onSendMessage(chatProvider, stickerName, TypeMessage.sticker),
      child: Image.asset(
        'images/$stickerName.gif',
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildInput(_chatProvider) {
    return Container(
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.only(left: 4.0),
            child: IconButton(
              icon: Icon(Icons.image_outlined),
              onPressed: () {
                _pickImage().then((isSuccess) {
                  if (isSuccess) _uploadFile(_chatProvider);
                });
              },
              color: PRIMARY_COLOR,
            ),
          ),
          Flexible(
            child: Container(
              child: TextField(
                onSubmitted: (_) {
                  _onSendMessage(chatProvider, _chatInputController.text, TypeMessage.text);
                },
                style: TextStyle(fontSize: 16.0),
                controller: _chatInputController,
                decoration: InputDecoration.collapsed(hintText: ''),
                focusNode: _focusNode,
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.0),
            child: IconButton(
              icon: Icon(Icons.send),
              onPressed: () => _onSendMessage(chatProvider, _chatInputController.text, TypeMessage.text),
              color: PRIMARY_COLOR,
            ),
          ),
        ],
      ),
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey, width: 0.5)), color: Colors.white),
    );
  }

  Widget _buildListMessage(_chatProvider) {
    return Flexible(
      child: _groupChatId.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: _chatProvider.getChatStream(_groupChatId, _limit),
              builder: (_, snapshot) {
                if (snapshot.hasData) {
                  _listMessage = snapshot.data!.docs;
                  if (_listMessage.length > 0) {
                    return ListView.builder(
                      padding: EdgeInsets.all(10),
                      itemBuilder: (_, index) => _buildItemMessage(index, snapshot.data?.docs[index]),
                      itemCount: snapshot.data?.docs.length,
                      reverse: true,
                      controller: _listScrollController,
                    );
                  } else {
                    return Center(child: Text("No message here yet..."));
                  }
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      color: PRIMARY_COLOR,
                    ),
                  );
                }
              },
            )
          : Center(
              child: CircularProgressIndicator(
                color: PRIMARY_COLOR,
              ),
            ),
    );
  }
}
