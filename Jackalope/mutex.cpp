/*
Copyright 2020 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include "mutex.h"

Mutex::Mutex() {
#if defined(WIN32) || defined(_WIN32) || defined(__WIN32)
  InitializeCriticalSection(&cs);
#endif
}

void Mutex::Lock() {
#if defined(WIN32) || defined(_WIN32) || defined(__WIN32)
  EnterCriticalSection(&cs);
#else
  mutex.lock();
#endif
}

void Mutex::Unlock() {
#if defined(WIN32) || defined(_WIN32) || defined(__WIN32)
  LeaveCriticalSection(&cs);
#else
  mutex.unlock();
#endif
}

//lock data for writing, no other readers or writers possible
void ReadWriteMutex::LockWrite() {
  mutex.lock();
}

//unlocks data after LockWrite
void ReadWriteMutex::UnlockWrite() {
  mutex.unlock();
}

//lock data for reading only, other readers possible, but no writers
void ReadWriteMutex::LockRead() {
  mutex.lock_shared();
}

//unlocks data after LockRead
void ReadWriteMutex::UnlockRead() {
  mutex.unlock_shared();
}
