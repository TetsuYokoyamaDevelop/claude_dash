class Project {
  final String name;
  final String path;

  const Project({required this.name, required this.path});

  Map<String, String> toJson() => {'name': name, 'path': path};

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        name: json['name'] as String,
        path: json['path'] as String,
      );
}
