# rails-8-template

For your AppDev Projects!

All files are covered by the MIT license, see [LICENSE.txt](LICENSE.txt).

## Account tiers (trip generation)

- **`regular`** (default on `users.account_tier`): at most **10** successful AI itinerary generations (**new trip** or **rebuild**) per **rolling 6 months**.
- **`premium`**: no limit (no rows are written to `trip_generation_events`).

Make a user premium in Rails console:

```ruby
User.find_by!(email: "you@example.com").update!(account_tier: "premium")
```
