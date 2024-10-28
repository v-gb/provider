type ('t, 'module_type, 'tag) t = ..

type same_witness =
  { f :
      't 'm1 'm2 'tag1 'tag2.
      ('t, 'm1, 'tag1) t -> ('t, 'm2, 'tag2) t -> ('m1, 'm2) Type.eq option
  }
