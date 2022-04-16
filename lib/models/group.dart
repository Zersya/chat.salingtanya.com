class Group {
  final String name;
  final List<String> members;
  final List<String> read;
  final List<String> write;
  final String id;
  final String collection;

  Group({
    required this.name,
    required this.members,
    required this.read,
    required this.write,
    required this.id,
    required this.collection,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      name: json['name'] as String,
      members: json['members'].cast<String>() as List<String>,
      read: json['\$read'].cast<String>() as List<String>,
      write: json['\$write'].cast<String>() as List<String>,
      id: json['\$id'] as String,
      collection: json['\$collection'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['name'] = name;
    data['members'] = members;
    data['\$read'] = read;
    data['\$write'] = write;
    data['\$id'] = id;
    data['\$collection'] = collection;
    return data;
  }
}
