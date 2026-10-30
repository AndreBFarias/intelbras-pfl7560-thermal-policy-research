#!/usr/bin/env bash
CONFIG_B64='W2luaXZlcnNpb25dClZlck51bWJlciAgICAgICAgICAgICA9IDE7CgpbR2xvYmFsXQpDT05GSUdfTU9ERUwgPSBLSk1fNUgwMzlfNDEyOwoj5rip5o6nClRIRVJNQUxfTUFOQUdFTUVOVCAgID0gWTsKI+iTneeJmemfs+eusQpCTFVFVE9PVEhfQ09OVFJPTExFUiA9IFk7CiPnga/pl6oKTEVEX0xJR0hUX0NZQ0xFUiAgICAgPSBOOwoj5omL5Yqo6LCD54SmCkZPQ1VTX0NPTlRST0xMRVIgICAgID0gWTsKI+iHquWKqOiwg+eEpgpBVVRPX0tFWVNUT05FX1NVUFBPUlQ9IFk7CiNjdXNf5a6a5Yi25aOw6Z+z5qih5byPCkNVU19TT1VORF9NT0RFX1NVUFBPUlQ9IFk7CgpbQlRTaW5rXQpVQVJUX1JFVFJZX1RJTUVTICA9IDM7CkVYVF9VQVJUX1RJTUVPVVQgID0gNDAwOwpCVF9ERUZBVUxUX1ZPTFVNRSA9IDB4MUI7CklOSVRJQUxJWkVSX0xJU1QgID0gOwoKW0JUU2lua0NtZGxpbmVdCkNNRExJTkVfTlVNID0gMTA7CiNDTURMSU5FX1BPV0VSX09GRgpDTURMSU5FXzBfVFlQRSAgPSAwOyMjMDpQT1dFUl9PRkYgMTpQT1dFUl9PTiAyOlZPTFVNRV9QTFVTIDM6Vk9MVU1FX01JTlUgNDpWT0xVTUUgNTpQUkVWIDY6TkVYVCA3OlBMQVlfUEFVU0UgODpWT0xVTUVfTVVURSA5Ok5PTkUKQ01ETElORV8wX05BTUUgID0gUE9XRVJfT0ZGOwpDTURMSU5FXzBfQ01EICAgPSAweDU1LCAweEFBLCAweDUyLCAweDA2LCAweDAwLCAweDVBOwpDTURMSU5FXzBfUkVQTFkgPSAweDA2OwojQ01ETElORV9QT1dFUl9PTgpDTURMSU5FXzFfVFlQRSAgPSAxOwpDTURMSU5FXzFfTkFNRSAgPSBQT1dFUl9PTjsKQ01ETElORV8xX0NNRCAgID0gMHg1NSwgMHhBQSwgMHg1MiwgMHgwNSwgMHgwMCwgMHg1QTsKQ01ETElORV8xX1JFUExZID0gMHgwNTsKI0NNRExJTkVfVk9MVU1FX1BMVVMKQ01ETElORV8yX1RZUEUgID0gMjsKQ01ETElORV8yX05BTUUgID0gVk9MVU1FX1BMVVM7CkNNRExJTkVfMl9DTUQgICA9IDB4NTUsIDB4QUEsIDB4NTIsIDB4MDAsIDB4MDAsIDB4NUE7CkNNRExJTkVfMl9SRVBMWSA9IDB4MDA7CiNDTURMSU5FX1ZPTFVNRV9NSU5VCkNNRExJTkVfM19UWVBFICA9IDM7CkNNRExJTkVfM19OQU1FICA9IFZPTFVNRV9NSU5VOwpDTURMSU5FXzNfQ01EICAgPSAweDU1LCAweEFBLCAweDUyLCAweDAxLCAweDAwLCAweDVBOwpDTURMSU5FXzNfUkVQTFkgPSAweDAxOwojQ01ETElORV9WT0xVTUUKQ01ETElORV80X1RZUEUgID0gNDsKQ01ETElORV80X05BTUUgID0gVk9MVU1FOwpDTURMSU5FXzRfQ01EICAgPSAweDU1LCAweEFBLCAweDUyLCAweDAzLCAweDFCLCAweDVBOwpDTURMSU5FXzRfUkVQTFkgPSAweDAzOwojQ01ETElORV9QUkVWCkNNRExJTkVfNV9UWVBFICA9IDU7CkNNRExJTkVfNV9OQU1FICA9IFBSRVY7CkNNRExJTkVfNV9DTUQgICA9IDB4NTUsIDB4QUEsIDB4NTIsIDB4MDQsIDB4MDAsIDB4NUE7CkNNRExJTkVfNV9SRVBMWSA9IDB4MDQsIDB4MDA7CiNDTURMSU5FX05FWFQKQ01ETElORV82X1RZUEUgID0gNjsKQ01ETElORV82X05BTUUgID0gTkVYVDsKQ01ETElORV82X0NNRCAgID0gMHg1NSwgMHhBQSwgMHg1MiwgMHgwNCwgMHgwMSwgMHg1QTsKQ01ETElORV82X1JFUExZID0gMHgwNCwgMHgwMTsKI0NNRExJTkVfUExBWV9QQVVTRQpDTURMSU5FXzdfVFlQRSAgPSA3OwpDTURMSU5FXzdfTkFNRSAgPSBQTEFZX1BBVVNFOwpDTURMSU5FXzdfQ01EICAgPSAweDU1LCAweEFBLCAweDUyLCAweDAyLCAweDAwLCAweDVBOwpDTURMSU5FXzdfUkVQTFkgPSAweDAyOwojQ01ETElORV9WT0xVTUVfTVVURQpDTURMSU5FXzhfVFlQRSAgPSA4OwpDTURMSU5FXzhfTkFNRSAgPSBWT0xVTUVfTVVURTsKQ01ETElORV84X0NNRCAgID0gMHg1NSwgMHhBQSwgMHg1MiwgMHgwMywgMHgwMCwgMHg1QTsKQ01ETElORV84X1JFUExZID0gMHgwMzsKI0NNRExJTkVfTk9ORQpDTURMSU5FXzlfVFlQRSAgPSA5OwpDTURMSU5FXzlfTkFNRSAgPSBOT05FOwpDTURMSU5FXzlfQ01EICAgPSA7CkNNRExJTkVfOV9SRVBMWSA9IDsKCltUaGVybWFsXQpUSEVSTUFMX01PREUgICAgPSAweDEwMDE7Ck1BWF9WQUxVRSAgICAgICA9IDEyMDAwMDsKTUlOX1ZBTFVFICAgICAgID0gLTQwMDAwOwpXQVJOSU5HX1ZBTFVFICAgPSAgNzAwMDA7CkVNRVJHRU5DWV9WQUxVRSA9ICA3NTAwMDsKREVGQVVMVF9QUk9URUNUID0gMjsjIzA6b2ZmIDE6b24gMjppbWVkaWF0ZWx5IHBvd2Vyb2ZmCkRFRkFVTFRfTk9USUZZICA9IDM7IyMwOkVSUk9SX0xTQURDIDE6RVJST1JfVEhFUk1JU1RPUiAyOldBUk5JTkdfT1ZFUkhFQVQgMzpJTkZPX1RFTVBFUkFUVVJFCkJBQ0tMSUdIVF9FTiAgICA9IFk7ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAoKW0JhY2tsaWdodFBvbGljeV0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIApQT0xJQ1lfTlVNID0gMiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiNQT0xJQ1lfU1RBTkRBUkQgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKUE9MSUNZXzBfVFlQRSAgICAgICA9IDA7IyMwOlNUQU5EQVJEIDE6RU5FUkdZX1NBVklORyAgICAgICAgICAgICAgICAgICAgICAgClBPTElDWV8wX05BTUUgICAgICAgPSBTVEFOREFSRDsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKUE9MSUNZXzBfQ0xBU1MgICAgICA9IDA7IyMwOkxJTkUgMTpTVEVQICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgClBPTElDWV8wX1RIUkVTSE9MRCAgPSA2NjAwMCwgNjc1MDAsIDY5MDAwLCA3MDAwMCwgNzE1MDAsIDczMDAwOyAgICAgICAgICAgICAgICAgClBPTElDWV8wX0JSSUdIVE5FU1MgPSAgMTAwMCwgIDk1MCwgIDkwMCwgIDg1MCwgIDg1MCwgIDg1MDsKUE9MSUNZXzFfVFlQRSAgICAgICA9IDA7IyMwOlNUQU5EQVJEIDE6RU5FUkdZX1NBVklORyAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgClBPTElDWV8xX05BTUUgICAgICAgPSAyTkRfU1RBTkRBUkQ7ClBPTElDWV8xX0NMQVNTICAgICAgPSAwOyMjMDpMSU5FIDE6U1RFUCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIApQT0xJQ1lfMV9USFJFU0hPTEQgID0gNjYwMDAsIDY3NTAwLCA2OTAwMCwgNzAwMDAsIDcxNTAwLCA3MzAwMDsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKUE9MSUNZXzFfQlJJR0hUTkVTUyA9ICAxMDAwLCAgOTUwLCAgOTAwLCAgODUwLCAgODUwLCAgODUwOwoKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKW0JhY2tsaWdodF0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkhXX1BXTV9OVU0gICAgICAgICAgICAgID0gNTsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkhXX1BXTV9JTlZFUlNFICAgICAgICAgID0gTjsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgClNXX0JSSV9DVFJMICAgICAgICAgICAgID0gMjsjIzA6Q09OU1RBTlQgMTpHUElPX1NXSVRDSCAyOlBXTV9EVVRZIDM6STJDX0NNRCAgICAgICAgICAgICAgICAgClNXX0JSSV9TVEVQX0FESiAgICAgICAgID0gTjsjI046Li4uLi4uLi4uLiBZOi4uLi4uLi4uLi4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkRFRkFVTFRfUFdNX0ZSRVFVRU5DWSAgID0gMTgwMDsjI1BXTSBNb2RlLi4uLi4uLi4uLiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkRFRkFVTFRfUFdNX0RVVFkgICAgICAgID0gMTAwMDsjI1BXTSBNb2RlLi4uLi4uLi4uLi4uICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgRldfVDYgIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkZXX05BTUUgICAgICAgICAgICAgICAgID0gVDY7ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIApGV19MRVZFTCAgICAgICAgICAgICAgICA9IDc1MCwgODAwLCA4NTAsIDkwMCwgOTUwLCAxMDAwOwpGV19CUklHSFRORVNTX0NVUlZFICAgICA9IDc1MCwgODAwLCA4NTAsIDkwMCwgOTUwLCAxMDAwOwoKW1RoZXJtYWxQb2xpY3ldClBPTElDWV9OVU0gPSAyOwojIyMjIyMjIyMjIyMjIyMjIyMjIyMjCiMgICAwOlNUQU5EQVJECiMgICAxOkNPT0xJTkcKIyAgIDI6UVVJRVQKIyAgIDM6RkFTVAojICAgNDpOT05FCiMjIyMjIyMjIyMjIyMjIyMjIyMjIyMKI1BPTElDWV9TVEFOREFSRCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgClBPTElDWV8wX05BTUUgICAgICA9IFNUQU5EQVJEOyAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgClBPTElDWV8wX1RIUkVTSE9MRCA9IDI1MDAwLCAyNzAwMCwgMjkwMDAsICAzMTAwMCwgIDMzMDAwLCAgMzUwMDAsICAzNjAwMDsKUE9MSUNZXzBfU1BFRUQgICAgID0gICAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwOyAgICAgICAKI1BPTElDWV9OT05FClBPTElDWV8xX05BTUUgICAgICA9IDJORF9TVEFOREFSRDsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKUE9MSUNZXzFfVEhSRVNIT0xEID0gMjUwMDAsIDI3MDAwLCAyOTAwMCwgIDMxMDAwLCAgMzMwMDAsICAzNTAwMCwgIDM2MDAwOyAgICAgICAgICAgICAgICAgICAKUE9MSUNZXzFfU1BFRUQgICAgID0gICAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwLCAxMDAwOwoKW0F1dG9LZXlzdG9uZV0KRk9WICAgICAgICAgICAgICAgPSA0MjsjI+inhuWcuuinkkZPViwgRGVncmVlClZFUlRJQ0FMX0VOICAgICAgID0gWTsjI+WeguebtOaWueWQkeS9v+iDvQpIT1JJWk9OVEFMX0VOICAgICA9IE47IyPmsLTlubPmlrnlkJHkvb/og70KUk9UQVJZX0VOICAgICAgICAgPSBOOyMj5peL6L2s5pa55ZCR5L2/6IO9ClZFUlRJQ0FMX09GRlNFVCAgID0gMDsjI+WeguebtOaWueWQkeWBj+emuywg5Y2D5YiG5q+UCkhPUklaT05UQUxfT0ZGU0VUID0gMDsjI+awtOW5s+aWueWQkeWBj+emuywg5Y2D5YiG5q+UCkJZUEFTU19TRU5TT1JTICAgID0gTjsjI+S4jeS9v+eUqOS8oOaEn+WZqAoKW1RoZXJtaXN0b3JdClNFUklBTF9OVU0gPSAyOwoKW1RoZXJtaXN0b3JfMF0KSFdfTFNBRENfQ0hBTk5FTCA9IDE7CkhXX1ZfUkVGICAgICAgICAgPSAzLjM7CkhXX1ZfSU4gICAgICAgICAgPSAzLjM7CkhXX1IgICAgICAgICAgICAgPSA0Ljc7CkhXX1ZJUlRVQUxfQ0hBTk5FTCA9IDA7ClNXX0NMQVNTICAgICAgICAgPSAzOwpTV19OICAgICAgICAgICAgID0gMTA7CiMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgRldfWkwxMDNTQUYgIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjCiNOVEPng63mlY/nlLXpmLvpmLvlgLxS5ZKM57ud5a+55rip5bqmVOS5i+mXtOeahOWFs+ezu+WPr+eUqOS4i+W8j+ihqOekuu+8mgojICAgICAgICBsbiBSID0gbG4gYSArIEIvVAoj5YW25Lit77yaCiMgICBCID0gIDMzNDUuNjQ2OTM5IMKxIDYuNzIxCiNsbiBhID0gLTguOTY0NzkxOTM2IMKxIDAuMDIyMgojICAgciA9ICAwLjk5OTY3OTMyCkZXX05BTUUgICAgICAgICAgPSBaTDEwM1NBRjsKRldfTUlOX1RFTVAgICAgICA9IC00MDAwMDsKRldfTUFYX1RFTVAgICAgICA9IDEyMDAwMDsKRldfTlRDX0IgICAgICAgICA9IDMzNDUuNjQ2OTM5OwpGV19OVENfTE5hICAgICAgID0gLTguOTY0NzkxOTM2OwoKW1RoZXJtaXN0b3JfMV0KSFdfTFNBRENfQ0hBTk5FTCA9IDE7CkhXX1ZfUkVGICAgICAgICAgPSAzLjM7CkhXX1ZfSU4gICAgICAgICAgPSAzLjM7CkhXX1IgICAgICAgICAgICAgPSA0Ljc7CkhXX1ZJUlRVQUxfQ0hBTk5FTCA9IDE7ClNXX0NMQVNTICAgICAgICAgPSAzOyMjMDpOVEMgMTpDVVJWRSAyOlNXSVRDSEVSIDM6TVVYX05UQwpTV19OICAgICAgICAgICAgID0gMTA7CiMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgRldfWkwxMDNTQUYgIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjCiNOVEPIyMP0tefX6Nfo1rVSus2++LbUzsK2yFTWrrzktcS52M+1v8nTw8/Cyr2x7cq+o7oKIyAgICAgICAgbG4gUiA9IGxuIGEgKyBCL1QKI8bk1tCjugojICAgQiA9ICAzMzQ1LjY0NjkzOSChwCA2LjcyMQojbG4gYSA9IC04Ljk2NDc5MTkzNiChwCAwLjAyMjIKIyAgIHIgPSAgMC45OTk2NzkzMgpGV19OQU1FICAgICAgICAgID0gWkwxMDNTQUY7CkZXX01JTl9URU1QICAgICAgPSAtNDAwMDA7CkZXX01BWF9URU1QICAgICAgPSAxMjAwMDA7CkZXX05UQ19CICAgICAgICAgPSAzMzQ1LjY0NjkzOTsKRldfTlRDX0xOYSAgICAgICA9IC04Ljk2NDc5MTkzNjsKCltDb29saW5nRmFuXQpTRVJJQUxfTlVNID0gMjsKW0Nvb2xpbmdGYW5fMF0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIApERUZBVUxUX1BXTV9NT0RFICAgICAgPSBZOyMjWTpQV00gTjpHUElPIC4uLi4uLi4uLi4uLnNsYXZlYm9vdCAgICAgICAgICAgICAgICAgICAgICAgCkRFRkFVTFRfUFdNX0ZSRVFVRU5DWSA9IDM2MDAwOyMjUFdNIE1vZGUuLi4uLi4uLi4uLi4uLi4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKREVGQVVMVF9QV01fRFVUWSAgICAgID0gMTAwMDsjI1BXTSBNb2RlLi4uLi4uLi4uLi4uLi4uLi4uICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyBGV19ERkg4MDI1UyAjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkZXX05BTUUgICAgICAgICAgPSBERkg4MDI1UzsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKRldfUFdNX0RVVFkgICAgPSAgMjAwLCAzNTAsIDQ3NSwgNjAwLCA3MjUsIDg1MCwgMTAwMDsgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIApGV19TUEVFRF9DVVJWRSA9ICA1MDAsIDU3NSwgNjUwLCA3MjUsIDgyNSwgOTI1LCAxMDAwOyAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKW0Nvb2xpbmdGYW5fMV0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIApERUZBVUxUX1BXTV9NT0RFICAgICAgPSBZOyMjWTpQV00gTjpHUElPIC4uLi4uLi4uLi4uLnNsYXZlYm9vdCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkRFRkFVTFRfUFdNX0ZSRVFVRU5DWSA9IDM2MDAwOyMjUFdNIE1vZGUuLi4uLi4uLi4uLi4uLi4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKREVGQVVMVF9QV01fRFVUWSAgICAgID0gMTAwMDsjI1BXTSBNb2RlLi4uLi4uLi4uLi4uLi4uLi4uICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyBGV19ERkg4MDI1UyAjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgICAgICAgICAgICAgICAgICAgIApGV19OQU1FICAgICAgICAgID0gREZIODAyNVM7ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCkZXX1BXTV9EVVRZICAgID0gIDMyNSwgNDUwLCA1NzUsIDcyNSwgODc1LCA4NzUsIDEwMDA7ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKRldfU1BFRURfQ1VSVkUgPSAgNTAwLCA1NzUsIDY1MCwgNzI1LCA4MjUsIDkyNSwgMTAwMDsKCltEZWJ1Z1VhcnRdCkhXX1VBUlQxX1BPUlQgICAgICAgICAgICAgICA9IDA7IyMwOlBSSU1BUlkgMTpTRUNPTkRBUlkKREVGQVVMVF9CQUNLR1JPVURfT1ZFUkRVRSAgID0gLTE7IyMtMTpNQVggT1ZFUkRVRQpERUZBVUxUX1BSSU1BUllfQVNfVUFSVDEgICAgPSBOOwpTV19VQVJUMV9NT0RFICAgICAgICAgICAgICAgPSAwOyMjMDpPTkRFTUFORCAxOkVYQ0xVU0lWRQojIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIEZXX0FVVE9URVNUICMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIwpGV19OQU1FICAgICAgICAgID0gQVVUT1RFU1Q7CkZXX0JBVUQgICAgICAgICAgPSAxMTUyMDA7IzIzMDQwMCAxMTUyMDAgNTc2MDAgMzg0MDAgMTkyMDAgOTYwMCA0ODAwIDI0MDAgMTIwMCA2MDAgMzAwIDExMApGV19EQVRBX0JJVFMgICAgID0gODsjIzA6REVGQVVMVCA3OjdCSVQgODo4QklUCkZXX1NUT1BfQklUUyAgICAgPSAxOyMjMDpERUZBVUxUIDE6MUJJVCAyOjJCSVQKRldfUEFSSVRZICAgICAgICA9IE47IyNOOkRFRkFVTFQgTzpPREQgRTpFVkVOCgpbTW90b3JdCkhXX01PVE9SX0lOX0dQSU9fTlVNICAgICA9IEdQSU80XzYsIEdQSU83XzAsIEdQSU80XzUsIEdQSU80XzM7CkhXX01PVE9SX0VOX0dQSU9fTlVNICAgICA9IEdQSU8zXzM7CkhXX01PVE9SX0ZBVUxUX0dQSU9fTlVNICA9IEdQSU9fSU5WQUxJRDsKSFdfTU9UT1JfTEVOU19SX0dQSU9fTlVNID0gR1BJTzRfMjsKSFdfTU9UT1JfTEVOU19MX0dQSU9fTlVNID0gR1BJTzJfNzsKSFdfTU9UT1JfRU5fUE9MQVJJVFkgICAgID0gMTsKSFdfTU9UT1JfRkFVTFRfUE9MQVJJVFkgID0gMDsKSFdfTU9UT1JfTEVOU19SX1BPTEFSSVRZID0gMTsKSFdfTU9UT1JfTEVOU19MX1BPTEFSSVRZID0gMTsKU1dfTU9ERSAgICAgICAgICAgICAgICAgID0gMjsjIzA6U0lOR0xFIDE6RE9VQkxFIDI6U0lOR0xFX0RPVUJMRQpTV19VTklUICAgICAgICAgICAgICAgICAgPSAxOyMjMDpQRVJDRU5UQUdFIDE6U1RFUApTV19MSU1JVCAgICAgICAgICAgICAgICAgPSAweDM7IyMweDE6TEVOU19MIDB4MjpMRU5TX1IgMHg0OlNURVBfTUlOIDB4ODpTVEVQX01BWApTV19UT1JRVUVfREVMQVlfVVMgICAgICAgPSAxMDAwOwpTV19TVEVQX1JBTkdFICAgICAgICAgICAgPSAxMjAwMDsKU1dfU1RFUF9SQU5HRV9UT0xFUkFOQ0UgID0gNTAwOwpTV19MSU1JVF9UT0xFUkFOQ0VfU1RFUCAgPSAzMjsjI+i9rOWKqOWkmuWwkeatpeaJjeWPr+S7peemu+W8gOmZkOS9jQpTV19JTlRFUlZBTF9TVEVQICAgICAgICAgPSA4MDsKU1dfRElSX0NIQU5HRV9TVEVQICAgICAgID0gMzI7ClNXX1NUQVJUX0RFTEFZX1VTICAgICAgICA9IDA7IyPlkK/liqjooaXlgb/lpJrlsJHlvq7np5IKU1dfQlJBS0VfREVMQVlfVVMgICAgICAgID0gMTAwMDA7IyPliLnovabooaXlgb/lpJrlsJHlvq7np5IKIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyBGV18yNEJZSjI4ICMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIwpGV19OQU1FICAgICAgICAgICAgICAgICAgPSAyNEJZSjI4OwpGV19XSU5ESU5HX1BIQVNFUyAgICAgICAgPSA0OwpGV19SRVNPTFVUSU9OX1NURVAgICAgICAgPSA2NDsKRldfR0VBUl9SRURVQ1RJT05fUkFUSU8gID0gNjQ7CkZXX0RSSVZFX1NFUVVFTkNFXzAgICAgICA9IDBiMDAwMSwgMGIwMDEwLCAwYjAxMDAsIDBiMTAwMDsjI2ZvciBNT0RFX0ZVTExfU1RFUF9TSU5HTEUKRldfRFJJVkVfU0VRVUVOQ0VfMSAgICAgID0gMGIwMDExLCAwYjAxMTAsIDBiMTEwMCwgMGIxMDAxOyMjZm9yIE1PREVfRlVMTF9TVEVQX0RPVUJMRQpGV19EUklWRV9TRVFVRU5DRV8yICAgICAgPSAwYjAwMDEsIDBiMDAxMSwgMGIwMDEwLCAwYjAxMTAsIDBiMDEwMCwgMGIxMTAwLCAwYjEwMDAsIDBiMTAwMTsjI2ZvciBNT0RFX0hBTEZfU1RFUF9TSU5HTEVfRE9VQkxFCkZXX0RSSVZFX1NFUVVFTkNFX1NUT1AgICA9IDBiMTExMTsjZm9yIFNUT1AKCltPcmllbnRhdGlvbl0KSFdfSTJDX05VTSAgICAgICAgICAgICAgPSA0OwpTV19TSEFLRV9USFJFU0hPTEQgICAgICA9IDAuMSwgMC4xLCAwLjE7ClNXX1JPVEFURV9USFJFU0hPTEQgICAgID0gMTAuMCwgMTAuMCwgMTAuMDsKU1dfVElMVF9USFJFU0hPTEQgICAgICAgPSAxLjA7ClNXX0FDQ0VMX1NUQUJMRV9NUyAgICAgID0gMTAwMDsKU1dfR1lST19TVEFCTEVfTVMgICAgICAgPSAxMjUwOwpTV19PUklFTlRfU1RBQkxFX01TICAgICA9IDc1MDsKU1dfT1JJRU5UX0lETEVfTVMgICAgICAgPSAxMDAwOwpTV19QT0xMX0lOVEVSVkFMX01TICAgICA9IDEwMDsKU1dfUE9MTF9JTlRFUlZBTF9NQVhfTVMgPSAyNTA7CiMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgRldfSU1VICMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIwoj5bCG5LiJ6L205Yqg6YCf5bqm5ZKM5LiJ6L206ZmA6J665Luq55qE5Y6f5aeL5pWw5o2u6J6N5ZCI6K6h566X5Ye65qyn5ouJ6KeSCkZXX05BTUUgICAgICAgICAgICAgICAgID0gSU1VOwpGV19BWElTX01BUFBJTkcgICAgICAgICA9IC1ZLy1YLy1aOyMjK1gvLVkvK1o65Y+N6L2sWei9tCArWS8rWC8rWjrkuqTmjaJYWei9tCArWS8rWC8tWjrkuqTmjaJYWei9tOW5tuWPjei9rFrovbQKRldfQUNDRUxfQklBUyAgICAgICAgICAgPSAwLjAsIDAuMCwgMC4wOwpGV19FWFRSQV9MSUIgICAgICAgICAgICA9IGxpYm5sc2Vuc29yX2ltdS5zbzsKCltNdWx0aXBsZXhlcl0KSFdfTVVYX0lOX0dQSU9fTlVNICAgICAgPSBHUElPNF80OyMjyv2+3dGh1PHG97XER1BJT7HgusUKREVGQVVMVF9TV0lUQ0hfREVMQVlfTVMgPSAyMDA7IyPErMjPx9C7u7rztci0/bbgydm6wcPrCkRFRkFVTFRfU0VMRUNUX0NIQU5ORUwgID0gMDsjI8SsyM/RodTxtcTNqLXACiMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMgRldfQkwxNTUxQiAjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMKRldfTkFNRSAgICAgICAgICAgICAgICAgPSBCTDE1NTFCOwpGV19EUklWRV9HUElPU19DT1VOVCAgICA9IDE7IyPK/b7d0aHU8cb3tcRHUElPyuTI68/fyv0KRldfRFJJVkVfVEFCTEUgICAgICAgICAgPSAwYjAsIDBiMTsjI82otcC21NOmtcRHUElPtefGvQo='
# ============================================================================
#  Correcao definitiva - Projetor Intelbras PFL7560 (firmware V1.0.0.9 e V1.0.0.1)
#  METODO /vendor (permanente, SOBREVIVE a reset de fabrica; /vendor sem verity)
#
#  Aplica 3 fixes editando a particao /vendor direto por adb:
#   1. TERMICO  -> /vendor/etc/ZYCustom.ini  (ativa 2o sensor via mux, fans 100%,
#      brilho 100%, shutdown de protecao 75C). Config embutida (base64) neste .sh.
#   2. WI-FI    -> /vendor/build.prop  wifi_disconnect_on_boot=0 (reconecta sozinho)
#   3. XIRI     -> desabilita xiriservice em init.bigfish.rc (para o spam de log)
#  NAO toca no bootloader. Faz backup do stock antes de editar. Reversivel.
#
#  DOIS MODELOS (doc 42): o com USB-C (V1.0.0.9, CONFIG_MODEL KJM_5H039_412) e o sem
#  USB-C (V1.0.0.1, "NOTYPEC", KJM_5H039_412_INTELBRAS_NOTYPEC_TP). O script detecta
#  o modelo do aparelho (CONFIG_MODEL do ZYCustom.ini + ro.newlink.projectname) e usa
#  o ini corrigido e o stock DO MESMO MODELO. O build.prop de um nao serve ao outro
#  (zysys.typec* e o canal de OTA): o backup do modelo sem USB-C fica em
#  backups-projetor/notypec/ e o revert so restaura backup do modelo do aparelho;
#  modelo desconhecido ou sinais contraditorios = RECUSA, sem tocar em nada.
#
#  USO:
#    ./pfl7560-fix.sh status    # le o estado (nao muda nada)
#    ./pfl7560-fix.sh apply     # backup + aplica os 3 fixes no /vendor + reboot
#    ./pfl7560-fix.sh revert    # restaura o /vendor de fabrica (do backup) + reboot
#    PFL_IP=<ip> ./pfl7560-fix.sh apply   # se a busca automatica falhar
# ============================================================================
set -uo pipefail
MAC="${PFL_MAC:-}"; PORT=5555   # opcional: PFL_MAC=<mac> (nmap) ou PFL_IP=<ip> (recomendado)
# sub-rede a varrer: usa PFL_SUBNET; senao autodetecta a LAN da rota padrao (fallback 192.168.0.0/24)
_DEV="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
SUBNET="${PFL_SUBNET:-$(ip -o -f inet addr show dev "${_DEV:-lo}" 2>/dev/null | awk '{print $4}' | head -1)}"
SUBNET="${SUBNET:-192.168.0.0/24}"
HERE="$(cd "$(dirname "$0")" && pwd)"; BK="$HERE/backups-projetor"
ADB="$(command -v adb || true)"; [ -n "$ADB" ] || ADB="$HOME/Android/sdk/platform-tools/adb"
[ -x "$ADB" ] || { echo "ERRO: adb nao encontrado (sudo apt install adb)" >&2; exit 1; }
say(){ printf '\033[1;36m>> %s\033[0m\n' "$*" >&2; }
ok(){  printf '\033[1;32m[OK] %s\033[0m\n' "$*" >&2; }
err(){ printf '\033[1;31m[ERRO] %s\033[0m\n' "$*" >&2; }
# Re-tranca /vendor como somente-leitura. Chamado por trap EXIT no apply/revert:
# se o fluxo abortar no meio (qualquer exit) o /vendor nao fica gravavel ate o reboot.
# _RELOCK_DEV e global de proposito (o trap EXIT roda fora do escopo do local $d).
_RELOCK_DEV=""
relock(){ [ -n "${_RELOCK_DEV:-}" ] && "$ADB" -s "$_RELOCK_DEV" shell "mount -o ro,remount /vendor" >/dev/null 2>&1; return 0; }
RC="/vendor/etc/init/hw/init.bigfish.rc"; INI="/vendor/etc/ZYCustom.ini"; BP="/vendor/build.prop"
INI_STOCK_MD5="29d8ba36149413e899563029df078f6d"   # md5 do ZYCustom.ini de fabrica (stock)
INI_FIX_MD5="252ab7a72a007a8b79b3fc86bd5c0d19"      # md5 do ZYCustom.ini ja corrigido (a build) - doc do md5 esperado
BP_STOCK_MD5="fd8406c494c201e468a0401fa082027c"     # md5 do build.prop de fabrica (stock)
RC_STOCK_MD5="8f7e02b2f382ceed65cf058e56c0c302"     # md5 do init.bigfish.rc de fabrica (stock)
INI_STOCK_MD5_NOTYPEC="ed3f314ca89698cb057a74ef64dca38e"  # idem, modelo sem USB-C (V1.0.0.1)
INI_FIX_MD5_NOTYPEC="bdf5c4640596d1b2f2fb7f62fbadd6e3"    # ini corrigido do modelo sem USB-C
BP_STOCK_MD5_NOTYPEC="f5b24c1db546dcfb4340f485bf841c8e"    # build.prop de fabrica do modelo sem USB-C
ORIG_INI="$HERE/artifacts/ZYCustom.ini.ORIGINAL"        # stock versionado no repo
BP_STOCK_ART="$HERE/artifacts/build.prop.STOCK"         # stock versionado no repo
RC_STOCK_ART="$HERE/artifacts/init.bigfish.rc.STOCK"    # stock versionado no repo
ORIG_INI_NOTYPEC="$HERE/artifacts/ZYCustom.ini.NOTYPEC.STOCK"      # stock do modelo sem USB-C (doc 42)
BP_STOCK_ART_NOTYPEC="$HERE/artifacts/build.prop.NOTYPEC.STOCK"
FIX_INI_NOTYPEC="$HERE/artifacts/ZYCustom_390.NOTYPEC.ini"         # corrigido do modelo sem USB-C
BK_BASE="$BK"

# Modelo do aparelho. Define MODELO (antigo|novo) e as variaveis M_* do modelo, e troca
# BK para a pasta de backup DELE. Devolve !=0 (e nao toca em nada) se o modelo for
# desconhecido ou se os dois sinais (CONFIG_MODEL no ini e ro.newlink.projectname) se
# contradisserem. O ini pode ja estar corrigido por nos: o fix preserva o CONFIG_MODEL.
MODELO=""
detecta_modelo(){
  local d="$1" cfg prj mc mp
  cfg="$("$ADB" -s "$d" shell "grep -a '^CONFIG_MODEL' $INI | head -1" 2>/dev/null | tr -d '\r' \
         | sed -n 's/^CONFIG_MODEL[[:space:]]*=[[:space:]]*\([A-Za-z0-9_]*\).*/\1/p')"
  prj="$("$ADB" -s "$d" shell "getprop ro.newlink.projectname" 2>/dev/null | tr -d '\r\n ')"
  case "$cfg" in KJM_5H039_412) mc=antigo ;; KJM_5H039_412_INTELBRAS_NOTYPEC_TP) mc=novo ;; *) mc="" ;; esac
  case "$prj" in KJM_5H039_412_INTELBRAS_TP) mp=antigo ;; KJM_5H039_412_INTELBRAS_NOTYPEC_TP) mp=novo ;; *) mp="" ;; esac
  # um sinal PRESENTE e desconhecido (outro modelo) nao e compensado pelo outro sinal: recusa
  if { [ -n "$cfg" ] && [ -z "$mc" ]; } || { [ -n "$prj" ] && [ -z "$mp" ]; }; then mc=""; mp=""; fi
  if [ -n "$mc" ] && [ -n "$mp" ] && [ "$mc" != "$mp" ]; then
    err "sinais contraditorios sobre o modelo (CONFIG_MODEL='$cfg', ro.newlink.projectname='$prj') - recusado, nada foi alterado."; return 1
  fi
  MODELO="${mc:-$mp}"
  case "$MODELO" in
    antigo) M_INI_STOCK_MD5="$INI_STOCK_MD5"; M_BP_STOCK_MD5="$BP_STOCK_MD5"; M_ORIG_INI="$ORIG_INI"
            M_BP_ART="$BP_STOCK_ART"; BK="$BK_BASE" ;;
    novo)   M_INI_STOCK_MD5="$INI_STOCK_MD5_NOTYPEC"; M_BP_STOCK_MD5="$BP_STOCK_MD5_NOTYPEC"; M_ORIG_INI="$ORIG_INI_NOTYPEC"
            M_BP_ART="$BP_STOCK_ART_NOTYPEC"; BK="$BK_BASE/notypec" ;;
    *) err "modelo nao reconhecido (CONFIG_MODEL='$cfg', ro.newlink.projectname='$prj'): so conheco o V1.0.0.9 (KJM_5H039_412) e o V1.0.0.1 sem USB-C (..._NOTYPEC_TP) - recusado, nada foi alterado."; return 1 ;;
  esac
  ok "modelo do aparelho: $MODELO ($([ "$MODELO" = novo ] && echo 'V1.0.0.1, sem USB-C' || echo 'V1.0.0.9, com USB-C'))"
}

find_ip(){
  [ -n "${PFL_IP:-}" ] && { echo "$PFL_IP"; return 0; }
  if [ -z "$MAC" ]; then
    err "informe o IP do projetor: PFL_IP=<ip> $0 <comando>"
    err "(opcional: PFL_MAC=<mac> + nmap para busca automatica)"
    return 1
  fi
  command -v nmap >/dev/null || { err "sem nmap; use PFL_IP=<ip>"; return 1; }
  say "procurando o projetor (MAC $MAC)..."
  sudo nmap -sn -T4 "$SUBNET" >"/tmp/pfl.$$" 2>/dev/null||true
  local ip; ip="$(grep -i -B2 "$MAC" "/tmp/pfl.$$" 2>/dev/null|grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'|head -1)"; rm -f "/tmp/pfl.$$"
  [ -n "$ip" ] && { echo "$ip"; return 0; }
  err "nao achei. Ligue o projetor no Wi-Fi ou use PFL_IP=<ip>."; return 1
}
connect(){
  local ip dev u m; ip="$(find_ip)"||exit 1; case "$ip" in *:*) dev="$ip" ;; *) dev="$ip:$PORT" ;; esac   # PFL_IP pode ja trazer a porta
  "$ADB" connect "$dev" >/dev/null 2>&1; "$ADB" -s "$dev" wait-for-device >/dev/null 2>&1||true
  u="$("$ADB" -s "$dev" shell id 2>/dev/null|grep -oE 'uid=[0-9]+')"
  [ "$u" != "uid=0" ] && { "$ADB" -s "$dev" root >/dev/null 2>&1; sleep 2; "$ADB" connect "$dev" >/dev/null 2>&1; "$ADB" -s "$dev" wait-for-device >/dev/null 2>&1||true; }
  m="$("$ADB" -s "$dev" shell getprop ro.product.model 2>/dev/null|tr -d '\r\n ')"
  [ "$m" = "PFL7560" ] || { err "dispositivo em $ip NAO e PFL7560 (model='$m'). Abortando."; exit 1; }
  # root conferido DE VERDADE: o "adb root" pode falhar em silencio e o hidebug entao
  # responde errno = 13. So diz "(root)" se o id reler uid=0.
  u="$("$ADB" -s "$dev" shell id 2>/dev/null|grep -oE 'uid=[0-9]+')"
  [ "$u" = "uid=0" ] || { err "sem root em $ip (id devolveu '${u:-vazio}'): hidebug e escrita em /vendor nao funcionam. Abortando."; exit 1; }
  ok "conectado ao PFL7560 em $ip (root)"; echo "$dev"
}
cmd_status(){
  local d; d="$(connect)" || exit 1; [ -n "$d" ] || { err "sem dispositivo"; exit 1; }
  say "estado atual:"
  local hb; hb="$("$ADB" -s "$d" shell 'printf "custom\ngtc\ngtt 0\ngtt 1\ngfs 0\ngfs 1\ngbri 0\nquit\n"|/vendor/bin/hidebug' 2>/dev/null)"
  case "$hb" in *"errno = 13"*) err "hidebug negou acesso (errno = 13): sem root no aparelho" ;; esac
  printf '%s\n' "$hb"|grep -E "NTC|fan speed|brightness" >&2
  "$ADB" -s "$d" shell "grep -aE 'HW_VIRTUAL_CHANNEL|POLICY_0_SPEED|POLICY_0_THRESHOLD|POLICY_0_BRIGHTNESS' $INI; grep -a wifi_disconnect_on_boot $BP; getprop init.svc.xiriservice" 2>/dev/null >&2
}
# backup_stock <d> <nome> <device_path> <stock_md5> <artefato_versionado>
# Anti-envenenamento do backup do stock: se ja existe $BK/<nome>.STOCK nao-vazio, pula.
# Puxa o arquivo do device (aborta se o pull falhar ou vier vazio). Se o md5 do puxado
# casa o md5 stock conhecido, guarda o proprio pull como .STOCK. Senao (device ja
# modificado/corrigido ou md5 divergente) usa o artefato stock VERSIONADO do repo, mas
# so depois de validar que ele existe, e nao-vazio E tem o md5 stock esperado; se o
# artefato faltar/for invalido, aborta (nunca salva a versao modificada como .STOCK).
backup_stock(){
  local d="$1" nome="$2" dpath="$3" smd5="$4" art="$5" tmp bm
  [ -s "$BK/$nome.STOCK" ] && return 0
  tmp="$(mktemp)"
  "$ADB" -s "$d" pull "$dpath" "$tmp" >/dev/null 2>&1 || { err "falha ao puxar $nome ($dpath) - backup abortado"; rm -f "$tmp"; exit 1; }
  [ -s "$tmp" ] || { err "backup de $nome veio vazio - abortando (nao gravo backup invalido)"; rm -f "$tmp"; exit 1; }
  bm="$(md5sum "$tmp"|awk '{print $1}')"
  if [ "$bm" = "$smd5" ]; then
    mv "$tmp" "$BK/$nome.STOCK" || { err "falha ao gravar backup $nome"; rm -f "$tmp"; exit 1; }
    [ -s "$BK/$nome.STOCK" ] || { err "backup $nome ficou vazio"; exit 1; }
    ok "backup $nome (stock md5 $bm)"
  else
    rm -f "$tmp"
    say "o $nome do device NAO e o stock (md5 $bm) - usando o stock versionado do repo p/ o backup"
    { [ -s "$art" ] && [ "$(md5sum "$art"|awk '{print $1}')" = "$smd5" ]; } \
      || { err "device ja modificado e sem artefato stock valido ($art) - abortando p/ nao poluir o backup"; exit 1; }
    cp "$art" "$BK/$nome.STOCK" || { err "falha ao copiar artefato stock de $nome"; exit 1; }
    [ -s "$BK/$nome.STOCK" ] || { err "backup $nome ficou vazio apos copiar artefato"; exit 1; }
    ok "backup $nome (stock versionado md5 $smd5)"
  fi
}
cmd_apply(){
  local d tmp esperado; d="$(connect)" || exit 1; [ -n "$d" ] || { err "sem dispositivo"; exit 1; }
  detecta_modelo "$d" || exit 1
  mkdir -p "$BK" || { err "nao consegui criar $BK"; exit 1; }
  say "remontando /vendor rw"; "$ADB" -s "$d" remount >/dev/null 2>&1
  _RELOCK_DEV="$d"; trap relock EXIT   # qualquer abort daqui p/ frente re-tranca /vendor ro
  # backup do stock VALIDADO e FATAL (sem backup valido do stock nao tocamos no /vendor).
  # Anti-envenenamento p/ os 3 arquivos: se o md5 do device casa o stock, guarda o proprio
  # pull; senao (device ja modificado/corrigido) cai para o artefato stock VERSIONADO do repo,
  # nunca salvando a versao modificada como .STOCK (protege um revert futuro).
  backup_stock "$d" "ZYCustom.ini"    "$INI" "$M_INI_STOCK_MD5" "$M_ORIG_INI"
  backup_stock "$d" "build.prop"      "$BP"  "$M_BP_STOCK_MD5"   "$M_BP_ART"
  backup_stock "$d" "init.bigfish.rc" "$RC"  "$RC_STOCK_MD5"   "$RC_STOCK_ART"
  say "FIX 1: config termica -> $INI"
  tmp="$(mktemp)"
  if [ "$MODELO" = novo ]; then   # corrigido do modelo sem USB-C: o artefato versionado (CONFIG_MODEL dele)
    esperado="$INI_FIX_MD5_NOTYPEC"; cat "$FIX_INI_NOTYPEC" >"$tmp" 2>/dev/null
  else
    esperado="$INI_FIX_MD5"; printf '%s' "$CONFIG_B64"|base64 -d >"$tmp"
  fi
  [ -s "$tmp" ] || { err "config vazia"; rm -f "$tmp"; exit 1; }
  l="$(md5sum "$tmp"|awk '{print $1}')"
  # defesa: a config tem que bater o md5 do modelo (protege contra corrupcao do heredoc numa edicao futura do script)
  [ "$l" = "$esperado" ] || { err "config do modelo $MODELO diverge do md5 esperado ($l != $esperado) - nao vou gravar"; rm -f "$tmp"; exit 1; }
  # push atomico: grava em .new, confere md5 e so entao mv por cima (original intacto se cair no meio)
  "$ADB" -s "$d" push "$tmp" "$INI.new" >/dev/null 2>&1; rm -f "$tmp"
  r="$("$ADB" -s "$d" shell "md5sum $INI.new" 2>/dev/null|awk '{print $1}')"
  if [ "$l" = "$r" ]; then
    "$ADB" -s "$d" shell "chmod 644 $INI.new && mv $INI.new $INI"; ok "termico gravado (md5 $l)"
  else
    "$ADB" -s "$d" shell "rm -f $INI.new" >/dev/null 2>&1; err "md5 divergente ao gravar $INI - original intacto"; exit 1
  fi
  say "FIX 2: wifi -> wifi_disconnect_on_boot=0"
  tmp="$(mktemp)"
  "$ADB" -s "$d" pull "$BP" "$tmp" >/dev/null 2>&1
  [ -s "$tmp" ] || { err "falha ao puxar $BP (veio vazio) - NAO vou editar wifi"; rm -f "$tmp"; exit 1; }
  if grep -q 'wifi_disconnect_on_boot=0' "$tmp"; then
    ok "wifi ja em 0"
  else
    sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' "$tmp"
    grep -q 'wifi_disconnect_on_boot=0' "$tmp" || { err "sed do wifi nao aplicou - abortando sem tocar no device"; rm -f "$tmp"; exit 1; }
    lbp="$(md5sum "$tmp"|awk '{print $1}')"
    "$ADB" -s "$d" push "$tmp" "$BP.new" >/dev/null 2>&1
    rbp="$("$ADB" -s "$d" shell "md5sum $BP.new" 2>/dev/null|awk '{print $1}')"
    if [ "$lbp" = "$rbp" ]; then
      "$ADB" -s "$d" shell "chmod 644 $BP.new && mv $BP.new $BP"; ok "wifi gravado (md5 $lbp)"
    else
      "$ADB" -s "$d" shell "rm -f $BP.new" >/dev/null 2>&1; err "md5 divergente ao gravar $BP - original intacto"; rm -f "$tmp"; exit 1
    fi
  fi
  rm -f "$tmp"
  say "FIX 3: desabilita xiriservice (para o spam)"
  tmp="$(mktemp)"; "$ADB" -s "$d" pull "$RC" "$tmp" >/dev/null 2>&1
  # BOOT-CRITICO: se o pull falhar o $tmp fica vazio; NUNCA sobrescrever o init.rc com um arquivo vazio.
  [ -s "$tmp" ] || { err "falha ao puxar $RC (veio vazio) - NAO vou sobrescrever o init.rc"; rm -f "$tmp"; exit 1; }
  if grep -A1 'service xiriservice' "$tmp" | grep -q 'disabled'; then ok "xiri ja desabilitado"
  else
    sed -i '/^service xiriservice \/system\/bin\/xiriservice/a\    disabled' "$tmp"
    grep -A1 'service xiriservice' "$tmp" | grep -q 'disabled' || { err "sed do xiri nao aplicou - abortando sem tocar no device"; rm -f "$tmp"; exit 1; }
    lrc="$(md5sum "$tmp"|awk '{print $1}')"
    "$ADB" -s "$d" push "$tmp" "$RC.new" >/dev/null 2>&1
    rrc="$("$ADB" -s "$d" shell "md5sum $RC.new" 2>/dev/null|awk '{print $1}')"
    if [ "$lrc" = "$rrc" ]; then
      "$ADB" -s "$d" shell "chmod 644 $RC.new && mv $RC.new $RC"; ok "xiri desabilitado"
    else
      "$ADB" -s "$d" shell "rm -f $RC.new" >/dev/null 2>&1; err "md5 divergente ao gravar $RC - original intacto"; rm -f "$tmp"; exit 1
    fi
  fi
  rm -f "$tmp"
  # valida os 3 estados relendo do device ANTES de declarar sucesso/reiniciar (sem falso-sucesso parcial)
  say "validando o resultado no device antes de reiniciar"
  "$ADB" -s "$d" shell "grep -q 'HW_VIRTUAL_CHANNEL = 1' $INI" || { err "validacao: termico nao confirmado em $INI"; exit 1; }
  # escada de brilho (dimming graduado ancorado no gtt1): piso 850 em 70C = WARNING_VALUE
  "$ADB" -s "$d" shell "grep -q '= 66000, 67500, 69000, 70000, 71500, 73000' $INI" || { err "validação: escada de brilho não confirmada em $INI"; exit 1; }
  # as fans tem de continuar 100% incondicional (7 degraus em 1000)
  "$ADB" -s "$d" shell "grep -q 'POLICY_0_SPEED     =   1000, 1000, 1000, 1000, 1000, 1000, 1000' $INI" || { err "validação: fans não estao 100% em todos os degraus"; exit 1; }
  "$ADB" -s "$d" shell "grep -q wifi_disconnect_on_boot=0 $BP" || { err "validacao: wifi_disconnect_on_boot=0 nao confirmado em $BP"; exit 1; }
  "$ADB" -s "$d" shell "grep -A1 'service xiriservice' $RC | grep -q disabled" || { err "validacao: xiriservice disabled nao confirmado em $RC"; exit 1; }
  ok "os 3 fixes confirmados no /vendor"
  "$ADB" -s "$d" shell sync
  say "reiniciando (o Wi-Fi reconecta sozinho com o fix)"
  "$ADB" -s "$d" reboot >/dev/null 2>&1||true
  ok "APLICADO no /vendor (permanente). Apos o boot: fans 1000 sempre, gtt1 ~59-63C, brilho 1000 no"
  ok "patamar normal caindo a 850 entre 66C e 70C (volta sozinho na descida), wifi auto, sem spam."
}
cmd_revert(){
  local d fail; d="$(connect)" || exit 1; [ -n "$d" ] || { err "sem dispositivo"; exit 1; }
  # o revert e POR MODELO: o build.prop do V1.0.0.9 (zysys.typec*, canal de OTA com USB-C) num
  # aparelho sem USB-C daria a ele uma entrada fantasma e o canal de atualizacao errado.
  detecta_modelo "$d" || exit 1
  # exige os TRES backups existentes E nao-vazios antes de tocar em qualquer coisa
  for n in ZYCustom.ini build.prop init.bigfish.rc; do
    [ -s "$BK/$n.STOCK" ] || { err "backup ausente ou vazio: $BK/$n.STOCK - revert abortado (rode apply neste PC com este aparelho, ou reverta reflashando o .bin de fabrica DO MODELO $MODELO)."; exit 1; }
  done
  # e o backup tem de SER do modelo do aparelho (md5 do ini e do build.prop de fabrica dele)
  for pair in "ZYCustom.ini:$M_INI_STOCK_MD5" "build.prop:$M_BP_STOCK_MD5"; do
    n="${pair%%:*}"
    [ "$(md5sum "$BK/$n.STOCK"|awk '{print $1}')" = "${pair##*:}" ] || { err "$BK/$n.STOCK nao e o $n de fabrica do modelo $MODELO (md5 esperado ${pair##*:}) - revert abortado, nada foi alterado."; exit 1; }
  done
  say "remontando /vendor rw e restaurando o stock (3 arquivos)"
  "$ADB" -s "$d" remount >/dev/null 2>&1
  _RELOCK_DEV="$d"; trap relock EXIT   # abort no meio do revert re-tranca /vendor ro
  fail=0
  for pair in "ZYCustom.ini:$INI" "build.prop:$BP" "init.bigfish.rc:$RC"; do
    n="${pair%%:*}"; p="${pair##*:}"
    lm="$(md5sum "$BK/$n.STOCK"|awk '{print $1}')"
    "$ADB" -s "$d" push "$BK/$n.STOCK" "$p.new" >/dev/null 2>&1
    rmt="$("$ADB" -s "$d" shell "md5sum $p.new" 2>/dev/null|awk '{print $1}')"
    if [ "$lm" = "$rmt" ]; then
      "$ADB" -s "$d" shell "chmod 644 $p.new && mv $p.new $p"; ok "restaurado $n"
    else
      "$ADB" -s "$d" shell "rm -f $p.new" >/dev/null 2>&1; err "md5 divergente ao restaurar $n - original intacto"; fail=1
    fi
  done
  [ "$fail" = "0" ] || { err "revert PARCIAL - nem tudo foi restaurado. NAO reiniciei. Reexecute o revert."; exit 1; }
  "$ADB" -s "$d" shell sync
  "$ADB" -s "$d" reboot >/dev/null 2>&1||true
  ok "REVERTIDO ao /vendor de fabrica (3 arquivos restaurados)."
}
case "${1:-status}" in status)cmd_status;; apply)cmd_apply;; revert)cmd_revert;; *) echo "uso: $0 [status|apply|revert]";exit 1;; esac
