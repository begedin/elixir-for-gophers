//go:build ignore

package db

// sqlc reads this SQL and generates the Go code below:
//
//	-- name: ListActiveUsers :many
//	SELECT id, name, email FROM users
//	WHERE active AND inserted_at > $1
//	ORDER BY name;

func (q *Queries) ListActiveUsers(ctx context.Context, since time.Time) ([]User, error) {
	rows, err := q.db.Query(ctx, listActiveUsers, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name, &u.Email); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, rows.Err()
}
