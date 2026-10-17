#![allow(dead_code)]

//! The X-ray zoo: one scene per memory idea. `xray-probe` sets a breakpoint
//! on every line marked `// xray:<scene>` and records a snapshot at each hit.

use std::cell::RefCell;
use std::collections::HashMap;
use std::hint::black_box;
use std::rc::{Rc, Weak};
use std::sync::{Arc, Barrier, Mutex};

struct Node {
    val: u32,
    next: Option<Box<Node>>,
}

#[derive(Debug)]
struct Point {
    x: i32,
    y: i32,
}

/// stack values, heap buffers, a Box chain, and references into all of them
fn basics() {
    let n = 42u64;
    let p = Point { x: 3, y: -4 };
    let arr = [1u8, 2, 3, 4];
    let v: Vec<u32> = vec![7, 8, 9];
    let s = String::from("hej");
    let list = Box::new(Node { val: 1, next: Some(Box::new(Node { val: 2, next: None })) });
    let r = &v;
    let third = &v[2];
    let tail = &v[1..];
    let px = &p.x;
    let name: &str = "static text";
    let maybe: Option<Box<u32>> = Some(Box::new(5));
    let nothing: Option<Box<u32>> = None;
    black_box((n, &arr, r, third, tail, px, name, &s, &list, &maybe, &nothing)); // xray:basics
}

/// a Vec outgrowing its buffer: watch the heap address change
fn growth() {
    let mut v: Vec<u64> = Vec::new();
    for i in 0..5u64 {
        v.push(i * 10);
        black_box(&v); // xray:growth
    }
}

/// Rc counts, RefCell borrow flags, and a Weak back pointer
fn shared() {
    let cell = Rc::new(RefCell::new(vec![1, 2]));
    let alias = Rc::clone(&cell);
    let weak: Weak<RefCell<Vec<i32>>> = Rc::downgrade(&cell);
    {
        let reading = cell.borrow();
        black_box(&reading); // xray:shared-borrowed
    }
    let mut writing = alias.borrow_mut();
    writing.push(3);
    black_box((&weak, &writing)); // xray:shared-mut
}

struct Parent {
    name: &'static str,
    children: RefCell<Vec<Rc<Child>>>,
}

struct Child {
    id: u8,
    parent: RefCell<Weak<Parent>>,
}

/// a tree with Weak back edges: no cycle of strong counts
fn tree() {
    let parent = Rc::new(Parent { name: "root", children: RefCell::new(Vec::new()) });
    for id in 0..2 {
        let child = Rc::new(Child { id, parent: RefCell::new(Weak::new()) });
        *child.parent.borrow_mut() = Rc::downgrade(&parent);
        parent.children.borrow_mut().push(child);
    }
    black_box(&parent); // xray:tree
}

/// threads sharing an Arc<Mutex<_>>, stopped while one holds the lock
fn threads() {
    let data = Arc::new(Mutex::new(vec![0u32; 3]));
    let gate = Arc::new(Barrier::new(3));
    let mut handles = Vec::new();
    for t in 0..2usize {
        let data = Arc::clone(&data);
        let gate = Arc::clone(&gate);
        handles.push(std::thread::spawn(move || {
            gate.wait();
            let mut guard = data.lock().unwrap();
            guard[t] += 1;
            black_box(&guard); // xray:threads
        }));
    }
    gate.wait();
    for h in handles {
        h.join().unwrap();
    }
    black_box(&data);
}

/// a small HashMap and a moved value
fn moves() {
    let mut ages: HashMap<&str, u8> = HashMap::new();
    ages.insert("li", 26);
    ages.insert("viktor", 25);
    let words = vec![String::from("a"), String::from("bc")];
    let taken = words; // `words` is moved-from now
    black_box((&ages, &taken)); // xray:moves
}

fn main() {
    basics();
    growth();
    shared();
    tree();
    threads();
    moves();
}
