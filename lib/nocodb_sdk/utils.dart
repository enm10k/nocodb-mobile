final _cloudHosts = [
  'app.nocodb.com',
  ...(const String.fromEnvironment('NC_CLOUD_HOSTS').split(',')),
];

bool isCloud(String host) => _cloudHosts.any((h) => host.contains(h));
