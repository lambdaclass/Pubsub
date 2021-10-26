use rustler::types::atom::{ok, error};
use rustler::{Encoder, Env, NifResult, Term};

use std::{thread, time};

use rand::prelude::*;

#[rustler::nif(schedule = "DirtyCpu")]
fn do_work(
    env: Env
) -> NifResult<Term> {
    let thread = thread::Builder::new()
        .name("do_some_work".to_string())
        .stack_size(1024 * 1024 * 8)
        .spawn(
            move || -> Result<(), String> {
                thread::sleep(time::Duration::from_secs(5));

                Ok(())
            },
        )
        .unwrap();

    let _ = thread.join();

    let num = rand::thread_rng().gen_range(0..10);

    if num <= 1 {
        Ok((error(), String::from("Random Error")).encode(env))
    } else {
        Ok(ok().encode(env))
    }
}

rustler::init!("Elixir.Pubsub.RustExpensiveCode", [do_work]);
