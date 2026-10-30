## A value that may be absent, including when T itself can be nil.
type Maybe*[T] = object
  present*: bool
  value*  : T
