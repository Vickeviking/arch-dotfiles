//! Every function here is refused by the borrow checker on purpose.
#![allow(unused)]

fn e0502_push_while_borrowed() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];
    v.push(4);
    println!("{first}");
}

fn e0499_two_mut() {
    let mut s = String::new();
    let a = &mut s;
    let b = &mut s;
    a.push('x');
    b.push('y');
}

fn e0382_use_after_move() {
    let name = String::from("li");
    let taken = name;
    println!("{name} {taken}");
}

fn e0505_move_while_borrowed() {
    let v = vec![1];
    let r = &v;
    let moved = v;
    println!("{r:?} {moved:?}");
}

fn e0506_assign_while_borrowed() {
    let mut n = 1;
    let r = &n;
    n = 2;
    println!("{r}");
}

fn e0597_does_not_live_long_enough() {
    let r;
    {
        let short = 5;
        r = &short;
    }
    println!("{r}");
}

fn e0716_temporary_dropped() {
    let s: &String;
    s = &String::from("temp");
    println!("{s}");
}

fn e0373_closure_may_outlive() -> std::thread::JoinHandle<()> {
    let data = vec![1, 2, 3];
    std::thread::spawn(|| println!("{data:?}"))
}

fn main() {}
