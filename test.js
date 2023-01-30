var a = [];
for (var i = 0; i < 10; i++) {
  a[i] =  (() => {console.log(i)}) ;
}
a[6](); // 10