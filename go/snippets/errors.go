//go:build ignore

package users

// Expected errors are values. Each step checks and wraps the error.
func LoadUser(ctx context.Context, id string) (User, error) {
	row, err := db.QueryUser(ctx, id)
	if err != nil {
		return User{}, fmt.Errorf("query user %s: %w", id, err)
	}

	user, err := parseUser(row)
	if err != nil {
		return User{}, fmt.Errorf("parse user %s: %w", id, err)
	}

	return user, nil
}
