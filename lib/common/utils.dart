// https://stackoverflow.com/questions/52632119/in-dart-syntactically-nice-way-to-cast-dynamic-to-given-type-or-return-null
T? cast<T>(x) => x is T ? x : null;
