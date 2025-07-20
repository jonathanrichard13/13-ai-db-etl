SELECT 
  u.*,
  a.email,
  ur.role,
  ud.division_name,
  (SELECT COUNT(*) FROM user_logs WHERE user_id = u.id) as log_count,
  (SELECT COUNT(*) FROM user_roles WHERE user_id = u.id) as role_count,
  (SELECT COUNT(*) FROM user_divisions WHERE user_id = u.id) as division_count
FROM users u
LEFT JOIN auth a ON u.auth_id = a.id
LEFT JOIN user_roles ur ON u.id = ur.user_id
LEFT JOIN user_divisions ud ON u.id = ud.user_id
WHERE u.id = 1001