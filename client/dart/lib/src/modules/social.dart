import '../model/user_response.dart';
import '../services/revani_base.dart';
import '../services/revani_database_serv.dart';
import '../source/api.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class RevaniSocialCommentsModel {
  final RevaniUserResponse? user;
  final String? text;
  final String? id;
  final String? postID;
  final List<String>? likes;
  final Map<String, dynamic>? moreData;
  RevaniSocialCommentsModel(
    this.user,
    this.text,
    this.likes,
    this.postID,
    this.id,
    this.moreData,
  );
  Map<String, dynamic> toJson() {
    return {
      "user": user?.toJson() ?? {},
      "text": text ?? "",
      "id": id ?? "",
      "likes": likes ?? [],
      "post": postID ?? "",
      "moreData": moreData ?? {},
    };
  }

  RevaniSocialCommentsModel copyWith({
    RevaniUserResponse? user,
    String? text,
    List<String>? likes,
    String? postID,
    String? id,
    Map<String, dynamic>? moreData,
  }) {
    return RevaniSocialCommentsModel(
      user ?? this.user,
      text ?? this.text,
      likes ?? this.likes,
      postID ?? this.postID,
      id ?? this.id,
      moreData ?? this.moreData,
    );
  }

  factory RevaniSocialCommentsModel.fromJson(Map<String, dynamic> data) {
    return RevaniSocialCommentsModel(
      data["user"] != null ? RevaniUserResponse.fromJson(data["user"]) : null,
      data["text"],
      (data["likes"] as List?)?.cast<String>() ?? [],
      data["postID"] ?? "",
      data["id"],
      data["moreData"] ?? {},
    );
  }
}

class RevaniSocialModel {
  final RevaniUserResponse? user;
  final String? text;
  final String? id;
  String? category;
  final List<String>? images;
  final List<String>? docs;
  final List<String>? locations;
  final List<String>? likes;
  final List<RevaniSocialCommentsModel>? comments;
  final Map<String, dynamic>? moreData;
  RevaniSocialModel({
    this.moreData,
    this.user,
    this.category,
    this.text,
    this.images,
    this.docs,
    this.locations,
    this.id,
    this.likes,
    this.comments,
  });
  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> coms = [];
    if (comments != null) {
      for (var element in comments!) {
        coms.add(element.toJson());
      }
    }

    return {
      "user": user?.toJson() ?? {},
      "text": text ?? "",
      "images": images ?? [],
      "docs": docs ?? [],
      "category": category ?? "",
      "locations": locations ?? [],
      "id": id ?? "",
      "moreData": moreData ?? {},
      "likes": likes ?? [],
      "comments": comments == null ? [] : coms,
    };
  }

  RevaniSocialModel copyWith({
    RevaniUserResponse? user,
    String? text,
    String? category,
    String? id,
    List<String>? images,
    List<String>? docs,
    List<String>? locations,
    List<String>? likes,
    List<RevaniSocialCommentsModel>? comments,
    Map<String, dynamic>? moreData,
  }) {
    return RevaniSocialModel(
      user: user ?? this.user,
      text: text ?? this.text,
      category: category ?? this.category,
      images: images ?? this.images,
      docs: docs ?? this.docs,
      locations: locations ?? this.locations,
      id: id ?? this.id,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      moreData: moreData ?? this.moreData,
    );
  }

  factory RevaniSocialModel.fromJson(Map<String, dynamic> data) {
    List<RevaniSocialCommentsModel> coms = [];
    for (var element in data["comments"]) {
      coms.add(RevaniSocialCommentsModel.fromJson(element));
    }

    return RevaniSocialModel(
      user: RevaniUserResponse.fromJson(data["user"]),
      text: data["text"] ?? "",
      images: data["images"] ?? [],
      category: data["category"] ?? "",
      docs: data["docs"] ?? [],
      locations: data["locations"] ?? [],
      id: data["id"] ?? "",
      likes: (data["likes"] as List?)?.cast<String>() ?? [],
      comments: coms,
      moreData: data["moreData"] ?? {},
    );
  }
}

class RevaniSocial {
  RevaniSocial();
  RevaniBaseDB database = RevaniBaseDB();
  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniData get db => revani.data;
  Future<RevaniResponse> createPost({
    required RevaniSocialModel postModel,
  }) async {
    String id = Uuid().v1();

    return await database.add(
      bucket: "social",
      tag: id,
      value: postModel.copyWith(id: id).toJson(),
    );
  }

  Future<RevaniResponse> editPost({
    required String id,
    required RevaniSocialModel postModel,
  }) async {
    return await database.update(
      bucket: "social",
      tag: id,
      newValue: postModel.copyWith(id: id).toJson(),
    );
  }

  Future<RevaniResponse> addLike({
    required RevaniUserResponse user,
    required String postID,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);
    if ((post.likes ?? []).contains(user.uid)) {
      return RevaniResponse(status: 200, message: "message");
    } else {
      List<String> likes = (post.likes ?? []);
      likes.add(user.uid);
      RevaniSocialModel newPost = post.copyWith(likes: likes);
      await editPost(id: postID, postModel: newPost);
      return RevaniResponse(status: 200, message: "message");
    }
  }

  Future<RevaniResponse> removeLike({
    required RevaniUserResponse user,
    required String postID,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);
    if ((post.likes ?? []).contains(user.uid)) {
      List<String> likes = (post.likes ?? []);
      likes.remove(user.uid);
      RevaniSocialModel newPost = post.copyWith(likes: likes);
      await editPost(id: postID, postModel: newPost);
      return RevaniResponse(status: 200, message: "message");
    } else {
      return RevaniResponse(status: 200, message: "message");
    }
  }

  Future<RevaniResponse> addComment({
    required RevaniSocialCommentsModel comment,
    required String postID,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);
    List<RevaniSocialCommentsModel> comments = [];
    comments = post.comments ?? [];
    comments.add(comment.copyWith(id: Uuid().v1()));
    RevaniSocialModel newPost = post.copyWith(comments: comments);
    await editPost(id: postID, postModel: newPost);
    return RevaniResponse(status: 200, message: "ok");
  }

  Future<RevaniResponse> deleteComment({
    required String commentID,
    required String postID,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);
    List<RevaniSocialCommentsModel> comments = [];
    comments = post.comments ?? [];
    comments.removeWhere((element) => element.id == commentID);
    RevaniSocialModel newPost = post.copyWith(comments: comments);
    await editPost(id: postID, postModel: newPost);
    return RevaniResponse(status: 200, message: "ok");
  }

  Future<RevaniResponse> addCommentLike({
    required RevaniUserResponse user,
    required String postID,
    required String commentID,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);

    List<RevaniSocialCommentsModel> comments = post.comments ?? [];
    bool updated = false;

    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == commentID) {
        List<String> commentLikes = comments[i].likes ?? [];

        if (!commentLikes.contains(user.uid)) {
          commentLikes.add(user.uid);
          comments[i] = RevaniSocialCommentsModel(
            comments[i].user,
            comments[i].text,
            commentLikes,
            comments[i].postID,
            comments[i].id,
            comments[i].moreData,
          );
          updated = true;
        }
        break;
      }
    }

    if (updated) {
      RevaniSocialModel newPost = post.copyWith(comments: comments);
      await editPost(id: postID, postModel: newPost);
      return RevaniResponse(status: 200, message: "Comment liked");
    }

    return RevaniResponse(
      status: 400,
      message: "No comments found or it's already liked.",
    );
  }

  Future<RevaniResponse> removeCommentLike({
    required RevaniUserResponse user,
    required String postID,
    required String commentID,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);

    List<RevaniSocialCommentsModel> comments = post.comments ?? [];
    bool updated = false;

    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == commentID) {
        List<String> commentLikes = comments[i].likes ?? [];

        if (commentLikes.contains(user.uid)) {
          commentLikes.remove(user.uid);
          comments[i] = RevaniSocialCommentsModel(
            comments[i].user,
            comments[i].text,
            commentLikes,
            comments[i].postID,
            comments[i].id,
            comments[i].moreData,
          );
          updated = true;
        }
        break;
      }
    }

    if (updated) {
      RevaniSocialModel newPost = post.copyWith(comments: comments);
      await editPost(id: postID, postModel: newPost);
      return RevaniResponse(status: 200, message: "Comment like removed");
    }

    return RevaniResponse(status: 400, message: "No comments or likes found.");
  }

  Future<List<RevaniSocialCommentsModel>> getComments({
    required String postID,
    int? limit,
    int? offset,
  }) async {
    RevaniSocialModel post = await getPost(id: postID);
    List<RevaniSocialCommentsModel> allComments = post.comments ?? [];

    if (offset != null && offset >= allComments.length) {
      return [];
    }

    int startIndex = offset ?? 0;
    int endIndex = limit != null ? startIndex + limit : allComments.length;

    if (endIndex > allComments.length) {
      endIndex = allComments.length;
    }

    if (startIndex >= endIndex) {
      return [];
    }

    return allComments.sublist(startIndex, endIndex);
  }

  Future<RevaniSocialModel> getPost({required String id}) async {
    var post = await database.get(bucket: "social", tag: id);
    return RevaniSocialModel.fromJson(post!.value);
  }

  Future<List<RevaniSocialModel>> getAllPost() async {
    List<RevaniSocialModel> list = [];
    var social = await database.getAll("social");
    for (var element in social) {
      list.add(RevaniSocialModel.fromJson(element.value));
    }

    return list;
  }
}
