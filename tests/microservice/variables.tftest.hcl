// variables {
//   var1 = "yolo"
// }

// run "plan_microservice" {
//   command = plan

//   variables {
//     var1 = var.var1
//   }

//   module {
//     source = "./"
//   }

//   #   assert {
//   #     condition     = true
//   #     error_message = ""
//   #   }

//   expect_failures = [
//     var.var1
//   ]
// }

// run "apply_microservice" {
//   command = apply

//   variables {
//     var1 = var.var1
//   }

//   module {
//     source = "./"
//   }
// }

// run "module_apply" {
//   command = apply

//   variables {
//     var1 = var.var1
//   }

//   module {
//     source = "../"
//   }
// }
