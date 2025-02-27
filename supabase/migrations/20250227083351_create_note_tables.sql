create sequence note_id_seq;

create table note (
    id bigint not null default nextval('note_id_seq'::regclass),
    note text not null,
    created_at timestamp with time zone null default current_timestamp,
    constraint notes_pkey primary key (id)
);
