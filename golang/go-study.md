

### 导入包，大写开头

在导入一个包时，你只能引用其中已导出的名字。任何“未导出”的名字在该包外均无法访问。

在 Go 中，如果一个名字以大写字母开头，那么它就是已导出的。

此处的math.pi 应该改为 math.Pi ，因为是使用的导入包
```bash

package main

import (
	"fmt"
	"math"
)

func main() {
	fmt.Println(math.pi)
}
```
