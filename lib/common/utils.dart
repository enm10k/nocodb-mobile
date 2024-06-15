// https://stackoverflow.com/questions/52632119/in-dart-syntactically-nice-way-to-cast-dynamic-to-given-type-or-return-null
T? cast<T>(final x) => x is T ? x : null;